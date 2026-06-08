import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Empty state widget với icon, mô tả và action tuỳ chọn.
class EmptyState extends StatelessWidget {
  final String? message;
  final String? title;
  final IconData? icon;
  final Widget? action;
  final bool compact;

  const EmptyState({
    super.key,
    this.message,
    this.title,
    this.icon,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 40.0 : 56.0;
    final color = theme.colorScheme.onSurface.withOpacity(0.35);
    final resolvedIcon = icon ?? FontAwesomeIcons.boxOpen;
    final isFontAwesome = resolvedIcon.fontFamily == 'FontAwesomeSolid' ||
        resolvedIcon.fontFamily == 'FontAwesomeRegular' ||
        resolvedIcon.fontFamily == 'FontAwesomeBrands';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isFontAwesome
                ? FaIcon(resolvedIcon, size: size, color: color)
                : Icon(resolvedIcon, size: size, color: color),
            SizedBox(height: compact ? 12 : 16),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message != null)
                    Text(
                      message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  if (action != null) ...[
                    SizedBox(height: compact ? 16 : 24),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
