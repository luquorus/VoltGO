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

  /// Get score color based on value
  /// 80-100: Green (Good)
  /// 60-79: Yellow/Orange (Fair)
  /// 40-59: Orange (Poor)
  /// 0-39: Red (Very Poor)
  String get scoreColor {
    if (score >= 80) return 'green';
    if (score >= 60) return 'orange';
    if (score >= 40) return 'deepOrange';
    return 'red';
  }

  /// Get score label
  String get scoreLabel {
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Very Poor';
  }
}

