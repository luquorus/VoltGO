import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/station_trust.dart';

/// Repository for Station Trust operations
class StationTrustRepository {
  final Ref ref;

  StationTrustRepository(this.ref);

  /// Get station trust by stationId
  Future<StationTrust> getStationTrust(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getStationTrust(stationId);
      return StationTrust.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get station trust: $e');
    }
  }

  /// Recalculate station trust
  Future<StationTrust> recalculateStationTrust(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.recalculateStationTrust(stationId);
      return StationTrust.fromJson(response);
    } catch (e) {
      throw Exception('Failed to recalculate station trust: $e');
    }
  }
}

