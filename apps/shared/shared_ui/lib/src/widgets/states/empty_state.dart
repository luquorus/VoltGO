import 'package:flutter/material.dart';

/// Empty state widget
class EmptyState extends StatelessWidget {
  final String? message;
  final IconData? icon;
  final Widget? action;

  const EmptyState({
    super.key,
    this.message,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
            ],
            if (message != null)
              Text(
                message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

