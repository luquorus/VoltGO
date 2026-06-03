import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/battery_swap_station.dart';
import '../models/pagination_response.dart';

/// Provider for battery swap stations list with pagination and optional search
final batterySwapStationsProvider =
    FutureProvider.family<PaginationResponse<BatterySwapStation>, ({int page, int size, String? search})>(
        (ref, params) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getBatterySwapStations(
    page: params.page,
    size: params.size,
    search: params.search,
  );

  final content = (response['content'] as List<dynamic>?)
          ?.map((json) =>
              BatterySwapStation.fromJson(json as Map<String, dynamic>))
          .toList() ??
      [];

  return PaginationResponse<BatterySwapStation>(
    content: content,
    totalElements: response['totalElements'] as int? ?? 0,
    totalPages: response['totalPages'] as int? ?? 0,
    size: response['size'] as int? ?? params.size,
    page: response['number'] as int? ?? params.page,
    first: response['first'] as bool? ?? false,
    last: response['last'] as bool? ?? false,
  );
});

/// Provider for a single battery swap station by ID
final batterySwapStationProvider =
    FutureProvider.family<BatterySwapStationDetail, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getBatterySwapStation(id);
  return BatterySwapStationDetail.fromJson(response);
});

/// Provider for current page
final batterySwapStationsPageProvider = StateProvider<int>((ref) => 0);

/// Provider for page size
final batterySwapStationsPageSizeProvider = StateProvider<int>((ref) => 20);

/// Provider for search query
final batterySwapStationsSearchProvider = StateProvider<String?>((ref) => null);
