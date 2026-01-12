import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station_trust.dart';
import '../repositories/station_trust_repository.dart';

/// Provider for station trust repository
final stationTrustRepositoryProvider = Provider<StationTrustRepository>((ref) {
  return StationTrustRepository(ref);
});

/// Provider for fetching station trust by stationId
final stationTrustProvider = FutureProvider.family<StationTrust, String>((ref, stationId) async {
  final repository = ref.watch(stationTrustRepositoryProvider);
  return await repository.getStationTrust(stationId);
});

