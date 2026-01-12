import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

/// Main Scaffold with Bottom Navigation Bar
/// Wraps screens that should show bottom navigation
class CollabMainScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBottomNav;
  final FloatingActionButton? floatingActionButton;

  const CollabMainScaffold({
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
      bottomNavigationBar: showBottomNav
          ? CollabBottomNavBar(currentLocation: currentLocation)
          : null,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButton != null && showBottomNav
          ? FloatingActionButtonLocation.endDocked
          : FloatingActionButtonLocation.endFloat,
    );
  }
}

