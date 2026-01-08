import 'package:flutter/material.dart';

/// Status pill that accepts string/enum mapping from app layer
/// 
/// App layer should provide color mapping function
class StatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Color Function(String)? colorMapper;

  const StatusPill({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.colorMapper,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Use provided color, or colorMapper, or default
    final pillColor = color ?? 
        (colorMapper?.call(label) ?? theme.colorScheme.primary);
    final pillBackgroundColor = backgroundColor ?? 
        pillColor.withOpacity(0.1);
    final textColor = color ?? 
        (colorMapper?.call(label) ?? theme.colorScheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pillBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pillColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

