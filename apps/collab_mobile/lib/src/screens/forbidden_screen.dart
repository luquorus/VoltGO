import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';

class ForbiddenScreen extends ConsumerWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return AppScaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Access Forbidden', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Your role (${authState.role ?? 'Unknown'}) does not have access.', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Logout',
                onPressed: () async {
                  await ref.read(authStateNotifierProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

