import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log.dart';
import '../models/pagination_response.dart';
import '../repositories/audit_log_repository.dart';

/// Provider for audit log repository
final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref);
});

/// Audit query filters
class AuditQueryFilters {
  final String? entityType;
  final String? entityId;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int size;

  AuditQueryFilters({
    this.entityType,
    this.entityId,
    this.from,
    this.to,
    this.page = 0,
    this.size = 20,
  });

  AuditQueryFilters copyWith({
    String? entityType,
    String? entityId,
    DateTime? from,
    DateTime? to,
    int? page,
    int? size,
    bool clearEntityType = false,
    bool clearEntityId = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AuditQueryFilters(
      entityType: clearEntityType ? null : (entityType ?? this.entityType),
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }
}

/// Provider for audit query filters
final auditQueryFiltersProvider = StateProvider<AuditQueryFilters>((ref) {
  return AuditQueryFilters();
});

/// Provider for querying audit logs with filters
final auditLogsQueryProvider = FutureProvider.family<PaginationResponse<AuditLogResponse>, AuditQueryFilters>((ref, filters) async {
  final repository = ref.watch(auditLogRepositoryProvider);
  return await repository.queryAuditLogs(
    entityType: filters.entityType,
    entityId: filters.entityId,
    from: filters.from,
    to: filters.to,
    page: filters.page,
    size: filters.size,
  );
});

/// Provider for fetching station audit logs
final stationAuditLogsProvider = FutureProvider.family<List<AuditLogResponse>, String>((ref, stationId) async {
  final repository = ref.watch(auditLogRepositoryProvider);
  return await repository.getStationAuditLogs(stationId);
});

/// Provider for fetching change request audit logs
final changeRequestAuditLogsProvider = FutureProvider.family<List<AuditLogResponse>, String>((ref, changeRequestId) async {
  final repository = ref.watch(auditLogRepositoryProvider);
  return await repository.getChangeRequestAuditLogs(changeRequestId);
});

