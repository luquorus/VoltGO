import 'package:flutter/material.dart';

/// Audit card showing action, time, and actor
class AuditCard extends StatelessWidget {
  final String action;
  final DateTime timestamp;
  final String? actorEmail;
  final String? actorRole;
  final Map<String, dynamic>? metadata;

  const AuditCard({
    super.key,
    required this.action,
    required this.timestamp,
    this.actorEmail,
    this.actorRole,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    action,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            if (actorEmail != null || actorRole != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (actorEmail != null)
                    Chip(
                      label: Text(actorEmail!),
                      avatar: const Icon(Icons.person, size: 16),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (actorRole != null)
                    Chip(
                      label: Text(actorRole!),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (metadata != null && metadata!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatMetadata(metadata!),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    return metadata.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}

