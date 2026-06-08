import 'package:flutter/material.dart';

/// Station Trust Summary Model
/// Represents the aggregate trust data across all stations
class StationTrustSummary {
  final int totalStations;
  final double averageScore;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final List<StationTrustStationSummary> topStations;
  final List<StationTrustStationSummary> bottomStations;

  StationTrustSummary({
    required this.totalStations,
    required this.averageScore,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
    required this.topStations,
    required this.bottomStations,
  });

  factory StationTrustSummary.fromJson(Map<String, dynamic> json) {
    return StationTrustSummary(
      totalStations: json['totalStations'] as int? ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      highCount: json['highCount'] as int? ?? 0,
      mediumCount: json['mediumCount'] as int? ?? 0,
      lowCount: json['lowCount'] as int? ?? 0,
      topStations: (json['topStations'] as List<dynamic>?)
              ?.map((e) => StationTrustStationSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bottomStations: (json['bottomStations'] as List<dynamic>?)
              ?.map((e) => StationTrustStationSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class StationTrustStationSummary {
  final String stationId;
  final String? stationName;
  final double score;

  StationTrustStationSummary({
    required this.stationId,
    this.stationName,
    required this.score,
  });

  factory StationTrustStationSummary.fromJson(Map<String, dynamic> json) {
    return StationTrustStationSummary(
      stationId: json['stationId'] as String? ?? '',
      stationName: json['stationName'] as String?,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get level {
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Very Poor';
  }
}
