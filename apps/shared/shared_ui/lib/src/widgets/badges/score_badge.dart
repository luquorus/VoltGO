import 'package:flutter/material.dart';

/// Score badge for trustScore/riskScore (0..100)
class ScoreBadge extends StatelessWidget {
  final int score;
  final String? label;
  final bool isTrustScore;

  const ScoreBadge({
    super.key,
    required this.score,
    this.label,
    this.isTrustScore = true,
  }) : assert(score >= 0 && score <= 100, 'Score must be between 0 and 100');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getScoreColor(score, isTrustScore);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(int score, bool isTrustScore) {
    if (isTrustScore) {
      // Trust score: higher is better (green)
      if (score >= 80) return Colors.green;
      if (score >= 60) return Colors.lightGreen;
      if (score >= 40) return Colors.orange;
      return Colors.red;
    } else {
      // Risk score: lower is better (inverse)
      if (score <= 20) return Colors.green;
      if (score <= 40) return Colors.lightGreen;
      if (score <= 60) return Colors.orange;
      return Colors.red;
    }
  }
}

