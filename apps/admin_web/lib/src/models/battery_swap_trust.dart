import 'package:flutter/material.dart';

/// Battery Swap Trust Model
/// Aligned with design spec: 4 components (Verification, Completion, Quality, Satisfaction)
/// and 5 tiers (Excellent, Good, Fair, Poor, New)
enum SwapTrustLevelTier { excellent, good, fair, poor, newEntity }

class BatterySwapTrust {
  final String stationId;
  final int score;
  final SwapTrustLevelTier level; // Excellent, Good, Fair, Poor, New
  final DateTime updatedAt;

  // 4 trust components
  final int? verificationScore; // weight: 30%
  final int? completionScore;    // weight: 25%
  final int? qualityScore;       // weight: 25%
  final int? satisfactionScore;  // weight: 20%

  // Sub-scores per component
  final int? passRate;           // verification sub
  final int? promptSubmission;    // verification sub
  final int? slaCompliance;       // completion sub
  final int? taskCompletionRate;  // completion sub
  final int? photoQualityScore;   // quality sub
  final int? inventoryAccuracy;   // quality sub
  final double? avgRating;        // satisfaction sub
  final int? complaintRate;       // satisfaction sub

  final Map<String, dynamic>? breakdown;

  BatterySwapTrust({
    required this.stationId,
    required this.score,
    required this.level,
    required this.updatedAt,
    this.verificationScore,
    this.completionScore,
    this.qualityScore,
    this.satisfactionScore,
    this.passRate,
    this.promptSubmission,
    this.slaCompliance,
    this.taskCompletionRate,
    this.photoQualityScore,
    this.inventoryAccuracy,
    this.avgRating,
    this.complaintRate,
    this.breakdown,
  });

  factory BatterySwapTrust.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>?;
    return BatterySwapTrust(
      stationId: json['stationId'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: _parseLevel(json['level'] as String?),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      verificationScore: (json['verificationScore'] as num?)?.toInt() ??
          (breakdown?['Verification'] as num?)?.toInt(),
      completionScore: (json['completionScore'] as num?)?.toInt() ??
          (breakdown?['Completion'] as num?)?.toInt(),
      qualityScore: (json['qualityScore'] as num?)?.toInt() ??
          (breakdown?['Quality'] as num?)?.toInt(),
      satisfactionScore: (json['satisfactionScore'] as num?)?.toInt() ??
          (breakdown?['Satisfaction'] as num?)?.toInt(),
      passRate: (json['passRate'] as num?)?.toInt(),
      promptSubmission: (json['promptSubmission'] as num?)?.toInt(),
      slaCompliance: (json['slaCompliance'] as num?)?.toInt(),
      taskCompletionRate: (json['taskCompletionRate'] as num?)?.toInt(),
      photoQualityScore: (json['photoQualityScore'] as num?)?.toInt(),
      inventoryAccuracy: (json['inventoryAccuracy'] as num?)?.toInt(),
      avgRating: (json['avgRating'] as num?)?.toDouble(),
      complaintRate: (json['complaintRate'] as num?)?.toInt(),
      breakdown: json['breakdown'] as Map<String, dynamic>?,
    );
  }

  static SwapTrustLevelTier _parseLevel(String? level) {
    switch ((level ?? '').toUpperCase()) {
      case 'EXCELLENT':
        return SwapTrustLevelTier.excellent;
      case 'GOOD':
        return SwapTrustLevelTier.good;
      case 'FAIR':
        return SwapTrustLevelTier.fair;
      case 'POOR':
        return SwapTrustLevelTier.poor;
      case 'NEW':
      case 'NEW_ENTITY':
        return SwapTrustLevelTier.newEntity;
      default:
        // Fallback: map old HIGH/MEDIUM/LOW to new tiers
        return SwapTrustLevelTier.fair;
    }
  }

  String get levelLabel {
    switch (level) {
      case SwapTrustLevelTier.excellent:
        return 'Excellent';
      case SwapTrustLevelTier.good:
        return 'Good';
      case SwapTrustLevelTier.fair:
        return 'Fair';
      case SwapTrustLevelTier.poor:
        return 'Poor';
      case SwapTrustLevelTier.newEntity:
        return 'New';
    }
  }

  Color get scoreColor {
    switch (level) {
      case SwapTrustLevelTier.excellent:
        return Colors.green.shade700;
      case SwapTrustLevelTier.good:
        return Colors.green;
      case SwapTrustLevelTier.fair:
        return Colors.orange;
      case SwapTrustLevelTier.poor:
        return Colors.red;
      case SwapTrustLevelTier.newEntity:
        return Colors.blue;
    }
  }

  IconData get levelIcon {
    switch (level) {
      case SwapTrustLevelTier.excellent:
        return Icons.stars;
      case SwapTrustLevelTier.good:
        return Icons.verified;
      case SwapTrustLevelTier.fair:
        return Icons.check_circle_outline;
      case SwapTrustLevelTier.poor:
        return Icons.warning;
      case SwapTrustLevelTier.newEntity:
        return Icons.fiber_new;
    }
  }

  Map<String, int?> get componentScores => {
        'Verification': verificationScore,
        'Completion': completionScore,
        'Quality': qualityScore,
        'Satisfaction': satisfactionScore,
      };
}
