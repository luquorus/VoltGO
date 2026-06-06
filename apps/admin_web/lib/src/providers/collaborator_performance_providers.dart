import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/collaborator_performance.dart';

/// Collaborator Performance Params
class CollaboratorPerformanceParams {
  final int page;
  final int size;
  final String? sortBy;
  final String? sortDir;

  CollaboratorPerformanceParams({
    this.page = 0,
    this.size = 20,
    this.sortBy,
    this.sortDir,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollaboratorPerformanceParams &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          size == other.size &&
          sortBy == other.sortBy &&
          sortDir == other.sortDir;

  @override
  int get hashCode => Object.hash(page, size, sortBy, sortDir);
}

/// Collaborator Performance List Provider
final collaboratorPerformanceListProvider = FutureProvider.family<Map<String, dynamic>, CollaboratorPerformanceParams>((ref, params) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }
  
  final response = await factory.admin.getCollaboratorsPerformance(
    page: params.page,
    size: params.size,
    sortBy: params.sortBy,
    sortDir: params.sortDir,
  );
  return response;
});

/// Collaborator Performance Detail Provider
final collaboratorPerformanceDetailProvider = FutureProvider.family<CollaboratorPerformanceDetail, String>((ref, collaboratorId) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }

  final response = await factory.admin.getCollaboratorPerformanceDetail(collaboratorId);
  return CollaboratorPerformanceDetail.fromJson(response);
});

/// Aggregated stats for leaderboard
class AggregatedPerformanceStats {
  final int totalTasks;
  final double avgPassRate;
  final double avgCompletionTime;
  final double slaComplianceRate;

  AggregatedPerformanceStats({
    required this.totalTasks,
    required this.avgPassRate,
    required this.avgCompletionTime,
    required this.slaComplianceRate,
  });
}

/// Aggregated stats provider
final aggregatedPerformanceStatsProvider = FutureProvider<AggregatedPerformanceStats>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client not initialized');
  }

  final response = await factory.admin.getCollaboratorsPerformance(page: 0, size: 1000);
  final collaborators = (response['content'] as List<dynamic>? ?? [])
      .map((e) => CollaboratorPerformance.fromJson(e as Map<String, dynamic>))
      .toList();

  if (collaborators.isEmpty) {
    return AggregatedPerformanceStats(
      totalTasks: 0,
      avgPassRate: 0.0,
      avgCompletionTime: 0.0,
      slaComplianceRate: 0.0,
    );
  }

  final totalTasks = collaborators.fold<int>(0, (sum, c) => sum + c.totalTasks);
  final avgPassRate = collaborators.fold<double>(0, (sum, c) => sum + c.passRate) / collaborators.length;
  final avgCompletionTime = collaborators.fold<double>(0, (sum, c) => sum + c.avgCompletionTimeHours) / collaborators.length;
  final slaComplianceRate = collaborators.fold<double>(0, (sum, c) => sum + c.slaComplianceRate) / collaborators.length;

  return AggregatedPerformanceStats(
    totalTasks: totalTasks,
    avgPassRate: avgPassRate,
    avgCompletionTime: avgCompletionTime,
    slaComplianceRate: slaComplianceRate,
  );
});
