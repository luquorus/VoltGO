import 'package:flutter/material.dart';

/// App Scaffold with standard app bar and optional loading overlay
class AppScaffold extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget body;
  final bool isLoading;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;

  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    this.leading,
    required this.body,
    this.isLoading = false,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              leading: leading,
              automaticallyImplyLeading: automaticallyImplyLeading,
              actions: actions,
            )
          : null,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Stack(
        children: [
          body,
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

