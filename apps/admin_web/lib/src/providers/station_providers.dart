import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_station.dart';
import '../models/pagination_response.dart';

/// Provider for stations list with pagination and optional search
final stationsProvider = FutureProvider.family<PaginationResponse<AdminStation>, ({int page, int size, String? search})>((ref, params) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getStations(
    page: params.page,
    size: params.size,
    search: params.search,
  );

  return PaginationResponse.fromJson(
    Map<String, dynamic>.from(response),
    AdminStation.fromJson,
  );
});

/// Provider for a single station by ID
final stationProvider = FutureProvider.family<AdminStation, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final dynamic raw = await factory.admin.getStation(id);

  Map<String, dynamic> data;
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map) {
      data = Map<String, dynamic>.from(first);
    } else {
      throw Exception('Station item is not a Map: ${first.runtimeType}');
    }
  } else if (raw is Map) {
    data = Map<String, dynamic>.from(raw);
  } else {
    throw Exception('Unexpected response type: ${raw.runtimeType}');
  }

  return AdminStation.fromJson(data);
});

/// Provider for current page
final stationsPageProvider = StateProvider<int>((ref) => 0);

/// Provider for page size
final stationsPageSizeProvider = StateProvider<int>((ref) => 20);

/// Provider for search query
final stationsSearchProvider = StateProvider<String?>((ref) => null);
