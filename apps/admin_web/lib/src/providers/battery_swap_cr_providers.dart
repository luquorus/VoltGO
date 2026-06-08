import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/battery_swap_change_request.dart';

/// Filter state for battery swap change requests
class BatterySwapCRFilters {
  final BatterySwapCRStatus? status;
  final BatterySwapRiskLevel? riskLevel;

  BatterySwapCRFilters({this.status, this.riskLevel});

  BatterySwapCRFilters copyWith({
    BatterySwapCRStatus? status,
    bool clearStatus = false,
    BatterySwapRiskLevel? riskLevel,
    bool clearRiskLevel = false,
  }) {
    return BatterySwapCRFilters(
      status: clearStatus ? null : (status ?? this.status),
      riskLevel: clearRiskLevel ? null : (riskLevel ?? this.riskLevel),
    );
  }
}

/// Provider for battery swap CR filters
final batterySwapCRFiltersProvider =
    StateProvider<BatterySwapCRFilters>((ref) => BatterySwapCRFilters());

/// Provider for battery swap change requests list
final batterySwapCRListProvider =
    FutureProvider<List<BatterySwapChangeRequest>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final filters = ref.watch(batterySwapCRFiltersProvider);

  // Filter by status if set
  final statusParam = filters.status?.name.toUpperCase();

  final response = await factory.admin.getBatterySwapChangeRequests(status: statusParam);
  
  List<BatterySwapChangeRequest> requests = (response)
      .map((json) => BatterySwapChangeRequest.fromJson(json as Map<String, dynamic>))
      .toList();

  // Apply risk level filter client-side (backend may not support this)
  if (filters.riskLevel != null) {
    requests = requests.where((cr) {
      final crRiskLevel = BatterySwapRiskLevel.fromScore(cr.riskScore);
      return crRiskLevel == filters.riskLevel;
    }).toList();
  }

  return requests;
});

/// Provider for a single battery swap change request by ID
final batterySwapCRProvider =
    FutureProvider.family<BatterySwapChangeRequest, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getBatterySwapChangeRequest(id);
  return BatterySwapChangeRequest.fromJson(response);
});
