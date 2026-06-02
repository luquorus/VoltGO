import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/battery_swap_trust.dart';

/// Repository for Battery Swap Trust operations
class BatterySwapTrustRepository {
  final Ref ref;

  BatterySwapTrustRepository(this.ref);

  /// Get battery swap trust score by stationId
  Future<BatterySwapTrust> getBatterySwapTrust(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getBatterySwapTrust(stationId);
      return BatterySwapTrust.fromJson(_mapBackendTrustResponse(response));
    } catch (e) {
      throw Exception('Failed to get battery swap trust: $e');
    }
  }

  /// Map backend breakdown keys to Flutter component names
  /// Backend: accuracy, reliability, safety, fairness, completeness, compliance
  /// Flutter: Verification, Completion, Quality, Satisfaction
  Map<String, dynamic> _mapBackendTrustResponse(Map<String, dynamic> response) {
    final mapped = Map<String, dynamic>.from(response);
    if (mapped['breakdown'] is Map) {
      final breakdown = Map<String, dynamic>.from(mapped['breakdown'] as Map);
      final mappedBreakdown = <String, dynamic>{
        'Verification': breakdown['accuracy'],
        'Completion': breakdown['reliability'],
        'Quality': breakdown['safety'],
        'Satisfaction': breakdown['fairness'],
      };
      mapped['breakdown'] = mappedBreakdown;
    }
    return mapped;
  }

  /// Get trust breakdown by dimension
  Future<Map<String, int>> getTrustBreakdown(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getBatterySwapTrustBreakdown(stationId);
      return Map<String, int>.from(response as Map);
    } catch (e) {
      throw Exception('Failed to get trust breakdown: $e');
    }
  }

  /// Get trust level
  Future<String> getTrustLevel(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getBatterySwapTrustLevel(stationId);
      return response;
    } catch (e) {
      throw Exception('Failed to get trust level: $e');
    }
  }

  /// Recalculate battery swap trust score
  Future<BatterySwapTrust> recalculateTrust(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.recalculateBatterySwapTrust(stationId);
      return BatterySwapTrust.fromJson(response);
    } catch (e) {
      throw Exception('Failed to recalculate trust: $e');
    }
  }
}

/// Provider for BatterySwapTrustRepository
final batterySwapTrustRepositoryProvider = Provider<BatterySwapTrustRepository>((ref) {
  return BatterySwapTrustRepository(ref);
});

/// Provider for battery swap trust score by stationId
final batterySwapTrustProvider =
    FutureProvider.family<BatterySwapTrust, String>((ref, stationId) async {
  final repository = ref.watch(batterySwapTrustRepositoryProvider);
  return repository.getBatterySwapTrust(stationId);
});

/// Provider for battery swap trust breakdown
final batterySwapTrustBreakdownProvider =
    FutureProvider.family<Map<String, int>, String>((ref, stationId) async {
  final repository = ref.watch(batterySwapTrustRepositoryProvider);
  return repository.getTrustBreakdown(stationId);
});

/// Provider for battery swap trust level
final batterySwapTrustLevelProvider =
    FutureProvider.family<String, String>((ref, stationId) async {
  final repository = ref.watch(batterySwapTrustRepositoryProvider);
  return repository.getTrustLevel(stationId);
});

/// Provider for battery swap trust summary (all stations)
final batterySwapTrustSummaryProvider = FutureProvider<BatterySwapTrustSummary>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  try {
    final response = await factory.admin.getBatterySwapTrustSummary();
    return BatterySwapTrustSummary.fromJson(response);
  } catch (e) {
    throw Exception('Failed to get trust summary: $e');
  }
});

/// Summary of battery swap trust scores across all stations
class BatterySwapTrustSummary {
  final int totalStations;
  final int excellentCount;
  final int goodCount;
  final int fairCount;
  final int poorCount;
  final int newCount;
  final double averageScore;
  final List<BatterySwapTrustStationSummary> topStations;
  final List<BatterySwapTrustStationSummary> bottomStations;

  // Backward-compat: high/medium/low aliases
  int get highCount => excellentCount + goodCount;
  int get mediumCount => fairCount;
  int get lowCount => poorCount + newCount;

  BatterySwapTrustSummary({
    required this.totalStations,
    required this.excellentCount,
    required this.goodCount,
    required this.fairCount,
    required this.poorCount,
    required this.newCount,
    required this.averageScore,
    required this.topStations,
    required this.bottomStations,
  });

  factory BatterySwapTrustSummary.fromJson(Map<String, dynamic> json) {
    return BatterySwapTrustSummary(
      totalStations: (json['totalStations'] as num?)?.toInt() ?? 0,
      excellentCount: (json['excellentCount'] as num?)?.toInt() ??
          (json['highCount'] as num?)?.toInt() ?? 0,
      goodCount: (json['goodCount'] as num?)?.toInt() ?? 0,
      fairCount: (json['fairCount'] as num?)?.toInt() ??
          (json['mediumCount'] as num?)?.toInt() ?? 0,
      poorCount: (json['poorCount'] as num?)?.toInt() ?? 0,
      newCount: (json['newCount'] as num?)?.toInt() ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      topStations: (json['topStations'] as List<dynamic>?)
              ?.map((e) => BatterySwapTrustStationSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bottomStations: (json['bottomStations'] as List<dynamic>?)
              ?.map((e) => BatterySwapTrustStationSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BatterySwapTrustStationSummary {
  final String stationId;
  final String? stationName;
  final int score;
  final String level;

  BatterySwapTrustStationSummary({
    required this.stationId,
    this.stationName,
    required this.score,
    required this.level,
  });

  factory BatterySwapTrustStationSummary.fromJson(Map<String, dynamic> json) {
    return BatterySwapTrustStationSummary(
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: json['level'] as String? ?? 'FAIR',
    );
  }
}
