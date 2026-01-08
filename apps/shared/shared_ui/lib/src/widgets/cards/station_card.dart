import 'package:flutter/material.dart';

/// Station card with title, subtitle, badges, and trailing slot
class StationCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? badges;
  final Widget? trailing;
  final VoidCallback? onTap;

  const StationCard({
    super.key,
    required this.title,
    this.subtitle,
    this.badges,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              if (badges != null && badges!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

