import 'package:flutter/material.dart';

/// Station Trust Model
/// Represents the trust score and breakdown for a station
class StationTrust {
  final String stationId;
  final double score; // 0..100
  final Map<String, dynamic> breakdown;
  final DateTime updatedAt;

  StationTrust({
    required this.stationId,
    required this.score,
    required this.breakdown,
    required this.updatedAt,
  });

  factory StationTrust.fromJson(Map<String, dynamic> json) {
    return StationTrust(
      stationId: json['stationId'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      breakdown: json['breakdown'] as Map<String, dynamic>? ?? {},
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'score': score,
      'breakdown': breakdown,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get levelLabel {
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Very Poor';
  }

  Color get scoreColor {
    if (score >= 80) return const Color(0xFF2E7D32); // green
    if (score >= 60) return const Color(0xFFEF6C00); // orange
    if (score >= 40) return const Color(0xFFE64A19); // deepOrange
    return const Color(0xFFC62828); // red
  }

  IconData get levelIcon {
    if (score >= 80) return Icons.verified;
    if (score >= 60) return Icons.check_circle_outline;
    if (score >= 40) return Icons.warning;
    return Icons.error_outline;
  }
}

