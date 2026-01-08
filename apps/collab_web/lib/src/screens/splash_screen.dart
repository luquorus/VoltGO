import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isAuthenticated && authState.role == 'COLLABORATOR') {
        context.go('/home');
      } else if (authState.isAuthenticated) {
        context.go('/forbidden');
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
            Text('VoltGo Collaborator Web', style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
      ),
    );
  }
}

