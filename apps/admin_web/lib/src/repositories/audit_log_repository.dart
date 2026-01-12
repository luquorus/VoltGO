import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/audit_log.dart';
import '../models/pagination_response.dart';

/// Repository for Audit Log operations
class AuditLogRepository {
  final Ref ref;

  AuditLogRepository(this.ref);

  /// Query audit logs with filters and pagination
  Future<PaginationResponse<AuditLogResponse>> queryAuditLogs({
    String? entityType,
    String? entityId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      // Format dates as ISO 8601 date-time format for Spring backend
      // Backend uses @DateTimeFormat(iso = ISO.DATE_TIME) with Instant
      // Spring requires ISO 8601 format with timezone (Z for UTC)
      // Format must be: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" or "yyyy-MM-dd'T'HH:mm:ss'Z'"
      String? formatDate(DateTime? date) {
        if (date == null) return null;
        // Convert to UTC first
        final utcDate = date.toUtc();
        // Format manually to ensure Z timezone is included
        // Format: "yyyy-MM-ddTHH:mm:ss.SSSZ" (ISO 8601 with Z)
        final year = utcDate.year.toString().padLeft(4, '0');
        final month = utcDate.month.toString().padLeft(2, '0');
        final day = utcDate.day.toString().padLeft(2, '0');
        final hour = utcDate.hour.toString().padLeft(2, '0');
        final minute = utcDate.minute.toString().padLeft(2, '0');
        final second = utcDate.second.toString().padLeft(2, '0');
        final millisecond = utcDate.millisecond.toString().padLeft(3, '0');
        return '$year-$month-${day}T$hour:$minute:$second.${millisecond}Z';
      }

      final response = await factory.admin.queryAuditLogs(
        entityType: entityType,
        entityId: entityId,
        from: formatDate(from),
        to: formatDate(to),
        page: page,
        size: size,
      );

      return PaginationResponse.fromJson(
        response as Map<String, dynamic>,
        (json) => AuditLogResponse.fromJson(json),
      );
    } catch (e) {
      throw Exception('Failed to query audit logs: $e');
    }
  }

  /// Get audit logs for a specific station
  Future<List<AuditLogResponse>> getStationAuditLogs(String stationId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getStationAuditLogs(stationId);
      return (response as List<dynamic>)
          .map((json) => AuditLogResponse.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get station audit logs: $e');
    }
  }

  /// Get audit logs for a specific change request
  Future<List<AuditLogResponse>> getChangeRequestAuditLogs(String changeRequestId) async {
    final factory = ref.read(apiClientFactoryProvider);
    if (factory == null) {
      throw Exception('API client not initialized');
    }

    try {
      final response = await factory.admin.getChangeRequestAuditLogs(changeRequestId);
      return (response as List<dynamic>)
          .map((json) => AuditLogResponse.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get change request audit logs: $e');
    }
  }
}

