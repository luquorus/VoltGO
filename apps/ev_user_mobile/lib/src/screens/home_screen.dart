import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';

/// Home screen placeholder
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return AppScaffold(
      title: 'Home',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
          onPressed: () async {
            await ref.read(authStateNotifierProvider.notifier).logout();
            if (context.mounted) {
              context.go('/login');
            }
          },
        ),
      ],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${authState.email ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Role: ${authState.role ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            const Text('Home screen - Coming soon'),
          ],
        ),
      ),
    );
  }
}

