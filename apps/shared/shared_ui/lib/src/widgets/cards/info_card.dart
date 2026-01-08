import 'package:flutter/material.dart';

/// Generic info card for displaying information
class InfoCard extends StatelessWidget {
  final String? title;
  final Widget? child;
  final List<Widget>? children;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const InfoCard({
    super.key,
    this.title,
    this.child,
    this.children,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
            ],
            if (child != null) child!,
            if (children != null) ...children!,
          ],
        ),
      ),
    );
  }
}

