import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';

/// Splash screen: check token/role -> redirect
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    // Check auth and redirect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isAuthenticated) {
        final role = authState.role;
        if (role == 'EV_USER' || role == 'PROVIDER') {
          context.go('/home');
        } else {
          context.go('/forbidden');
        }
      } else {
        context.go('/login');
      }
    });
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'VoltGo',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ],
        ),
      ),
    );
  }
}

