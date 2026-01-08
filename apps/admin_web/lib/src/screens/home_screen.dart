import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return AppScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(authStateNotifierProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${authState.email ?? 'Admin'}!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Role: ${authState.role ?? 'Unknown'}', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            const Text('Admin Dashboard - Coming soon'),
          ],
        ),
      ),
    );
  }
}

