import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/dashboard_stats.dart';

/// Dashboard Stats Provider
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getDashboardStats();
  return DashboardStats.fromJson(response);
});

/// Dashboard Trends Provider (family for different day ranges)
final trendsProvider = FutureProvider.family<Map<String, List<TrendDataPoint>>, int>((ref, days) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getDashboardTrends(days: days);
  final result = <String, List<TrendDataPoint>>{};
  
  final dailyBookings = (response['dailyBookings'] as List<dynamic>?) ?? [];
  result['dailyBookings'] = dailyBookings.map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>)).toList();
  
  final newStations = (response['newStations'] as List<dynamic>?) ?? [];
  result['newStations'] = newStations.map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>)).toList();
  
  final newUsers = (response['newUsers'] as List<dynamic>?) ?? [];
  result['newUsers'] = newUsers.map((e) => TrendDataPoint.fromJson(e as Map<String, dynamic>)).toList();
  
  return result;
});

/// Booking Stats Provider
final bookingStatsProvider = FutureProvider<BookingStats>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getBookingStats();
  return BookingStats.fromJson(response);
});

/// Issue Stats Provider
final issueStatsProvider = FutureProvider<IssueStats>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getIssueStats();
  return IssueStats.fromJson(response);
});

/// Trust Overview Params
class TrustOverviewParams {
  final int page;
  final int size;
  final String? sortBy;
  final String? sortDir;

  TrustOverviewParams({
    this.page = 0,
    this.size = 20,
    this.sortBy,
    this.sortDir,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrustOverviewParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          sortBy == other.sortBy &&
          sortDir == other.sortDir;

  @override
  int get hashCode => Object.hash(page, size, sortBy, sortDir);
}

/// Trust Overview Provider (family with params)
final trustOverviewProvider = FutureProvider.family<Map<String, dynamic>, TrustOverviewParams>((ref, params) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getTrustOverview(
    page: params.page,
    size: params.size,
    sortBy: params.sortBy,
    sortDir: params.sortDir,
  );
  return response;
});

/// Station Status Distribution Provider
final stationStatusDistributionProvider = FutureProvider<List<StationStatusDistribution>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getDashboardStats();
  final data = response['statusDistribution'] as List<dynamic>? ?? [];
  return data.map((e) => StationStatusDistribution.fromJson(e as Map<String, dynamic>)).toList();
});
