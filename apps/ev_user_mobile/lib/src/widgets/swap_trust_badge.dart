import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Trust level for battery swap stations
enum SwapTrustLevel {
  high,
  medium,
  low,
  unknown;

  static SwapTrustLevel fromScore(int? score) {
    if (score == null) return SwapTrustLevel.unknown;
    if (score >= 80) return SwapTrustLevel.high;
    if (score >= 50) return SwapTrustLevel.medium;
    return SwapTrustLevel.low;
  }

  static SwapTrustLevel fromString(String? level) {
    switch (level?.toUpperCase()) {
      case 'HIGH':
        return SwapTrustLevel.high;
      case 'MEDIUM':
        return SwapTrustLevel.medium;
      case 'LOW':
        return SwapTrustLevel.low;
      default:
        return SwapTrustLevel.unknown;
    }
  }

  Color get color {
    switch (this) {
      case SwapTrustLevel.high:
        return Colors.green;
      case SwapTrustLevel.medium:
        return Colors.orange;
      case SwapTrustLevel.low:
        return Colors.red;
      case SwapTrustLevel.unknown:
        return Colors.grey;
    }
  }

  String get label {
    switch (this) {
      case SwapTrustLevel.high:
        return 'High Trust';
      case SwapTrustLevel.medium:
        return 'Medium Trust';
      case SwapTrustLevel.low:
        return 'Low Trust';
      case SwapTrustLevel.unknown:
        return 'Trust Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case SwapTrustLevel.high:
        return FontAwesomeIcons.shieldHalved;
      case SwapTrustLevel.medium:
        return FontAwesomeIcons.shield;
      case SwapTrustLevel.low:
        return FontAwesomeIcons.shieldVirus;
      case SwapTrustLevel.unknown:
        return FontAwesomeIcons.circleQuestion;
    }
  }
}

/// Swap Trust Badge Widget - displays trust level for battery swap stations
class SwapTrustBadge extends StatelessWidget {
  final int? trustScore;
  final String? trustLevel;
  final bool compact;
  final VoidCallback? onTap;

  const SwapTrustBadge({
    super.key,
    this.trustScore,
    this.trustLevel,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = trustLevel != null
        ? SwapTrustLevel.fromString(trustLevel)
        : SwapTrustLevel.fromScore(trustScore);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: level.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(
          color: level.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            level.icon,
            color: level.color,
            size: compact ? 14 : 18,
          ),
          SizedBox(width: compact ? 6 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                level.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: level.color,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 13,
                ),
              ),
              if (!compact && trustScore != null)
                Text(
                  '$trustScore/100',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: level.color.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: badge,
      );
    }

    return badge;
  }
}

/// Swap Trust Card Widget - displays trust level in a card format
class SwapTrustCard extends StatelessWidget {
  final int? trustScore;
  final String? trustLevel;
  final String? stationName;
  final VoidCallback? onTap;

  const SwapTrustCard({
    super.key,
    this.trustScore,
    this.trustLevel,
    this.stationName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = trustLevel != null
        ? SwapTrustLevel.fromString(trustLevel)
        : SwapTrustLevel.fromScore(trustScore);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: level.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(
                  level.icon,
                  color: level.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Station Trust',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FaIcon(
                          FontAwesomeIcons.batteryFull,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: level.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (trustScore != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Trust score: $trustScore/100',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (stationName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        stationName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swap Trust Breakdown Widget - displays trust factors breakdown
class SwapTrustBreakdown extends StatelessWidget {
  final int totalScore;
  final int? verificationScore;
  final int? consistencyScore;
  final int? activityScore;

  const SwapTrustBreakdown({
    super.key,
    required this.totalScore,
    this.verificationScore,
    this.consistencyScore,
    this.activityScore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.chartPie,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trust Breakdown',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (verificationScore != null)
              _buildBreakdownRow(
                context,
                'Verification Rate',
                verificationScore!,
              ),
            if (consistencyScore != null)
              _buildBreakdownRow(
                context,
                'Consistency',
                consistencyScore!,
              ),
            if (activityScore != null)
              _buildBreakdownRow(
                context,
                'Activity Level',
                activityScore!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label, int score) {
    final theme = Theme.of(context);
    final color = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '$score/100',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
