import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../theme/collab_theme.dart';
import '../routing/app_router.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isAuthenticated && authState.role == 'COLLABORATOR') {
        context.go(CollabRoutes.tasks);
      } else if (authState.isAuthenticated) {
        context.go(CollabRoutes.forbidden);
      } else {
        context.go(CollabRoutes.login);
      }
    });
    
    return Scaffold(
      backgroundColor: CollabTheme.surfaceWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CollabTheme.primaryGreenLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.bolt,
                size: 64,
                color: CollabTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'VoltGo',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: CollabTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Collaborator Web',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(CollabTheme.primaryGreenLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
