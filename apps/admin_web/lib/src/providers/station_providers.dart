import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_station.dart';
import '../models/pagination_response.dart';

/// Provider for stations list with pagination
final stationsProvider = FutureProvider.family<PaginationResponse<AdminStation>, ({int page, int size})>((ref, params) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getStations(
    page: params.page,
    size: params.size,
  );
  
  final content = (response['content'] as List<dynamic>?)
      ?.map((json) => AdminStation.fromJson(json as Map<String, dynamic>))
      .toList() ?? [];
  
  return PaginationResponse<AdminStation>(
    content: content,
    totalElements: response['totalElements'] as int? ?? 0,
    totalPages: response['totalPages'] as int? ?? 0,
    size: response['size'] as int? ?? params.size,
    page: response['number'] as int? ?? params.page,
    first: response['first'] as bool? ?? false,
    last: response['last'] as bool? ?? false,
  );
});

/// Provider for a single station by ID
final stationProvider = FutureProvider.family<AdminStation, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getStation(id);
  return AdminStation.fromJson(response);
});

/// Provider for current page
final stationsPageProvider = StateProvider<int>((ref) => 0);

/// Provider for page size
final stationsPageSizeProvider = StateProvider<int>((ref) => 20);

