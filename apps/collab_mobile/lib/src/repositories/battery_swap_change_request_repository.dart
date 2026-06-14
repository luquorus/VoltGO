import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'change_request_repository.dart';

/// Repository for Battery-Swap Change Requests submitted by collaborators.
///
/// Routes through `CollaboratorMobileApiClient` (which targets
/// `/api/collab/mobile/battery-swap-change-requests/**`).
class BatterySwapChangeRequestRepository {
  final CollaboratorMobileApiClient apiClient;

  BatterySwapChangeRequestRepository(this.apiClient);

  ApiError _wrap(Object error, {String? fallbackMessage}) {
    if (error is ApiError) return error;
    return ApiError(
      traceId: '',
      code: 'UNKNOWN_ERROR',
      message: fallbackMessage ?? error.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// Get all battery-swap change requests owned by the current collaborator.
  Future<List<BatterySwapChangeRequestItem>> getMyChangeRequests() async {
    try {
      final response = await apiClient.getMyBatterySwapChangeRequests();
      return response
          .map((json) =>
              BatterySwapChangeRequestItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load battery-swap change requests.');
    }
  }

  /// Get full detail of a single battery-swap change request.
  Future<BatterySwapChangeRequestItem> getChangeRequest(String id) async {
    try {
      final response = await apiClient.getBatterySwapChangeRequest(id);
      return BatterySwapChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load change request detail.');
    }
  }

  /// Create a DRAFT battery-swap change request.
  Future<BatterySwapChangeRequestItem> createChangeRequest(
      Map<String, dynamic> data) async {
    try {
      final response = await apiClient.createBatterySwapChangeRequest(data);
      return BatterySwapChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Failed to create battery-swap change request.');
    }
  }

  /// Submit a DRAFT battery-swap change request for admin review.
  Future<BatterySwapChangeRequestItem> submitChangeRequest(String id) async {
    try {
      final response = await apiClient.submitBatterySwapChangeRequest(id);
      return BatterySwapChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Failed to submit battery-swap change request.');
    }
  }
}

/// Lightweight value object for a battery-swap CR list item.
class BatterySwapChangeRequestItem {
  final String id;
  final String type; // CREATE_BATTERY_SWAP_STATION, UPDATE_BATTERY_SWAP_STATION
  final String status;
  final String? stationId;
  final int? totalBatteries;
  final double? avgChargePowerKw;
  final String? operatingHours;
  final int? riskScore;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  const BatterySwapChangeRequestItem({
    required this.id,
    required this.type,
    required this.status,
    this.stationId,
    this.totalBatteries,
    this.avgChargePowerKw,
    this.operatingHours,
    this.riskScore,
    this.adminNote,
    this.createdAt,
    this.submittedAt,
    this.decidedAt,
  });

  factory BatterySwapChangeRequestItem.fromJson(Map<String, dynamic> json) {
    return BatterySwapChangeRequestItem(
      id: json['id'] as String,
      type: (json['type'] ?? 'UPDATE_BATTERY_SWAP_STATION') as String,
      status: (json['status'] ?? 'DRAFT') as String,
      stationId: json['stationId'] as String?,
      totalBatteries: (json['totalBatteries'] as num?)?.toInt(),
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      riskScore: (json['riskScore'] as num?)?.toInt(),
      adminNote: json['adminNote'] as String?,
      createdAt: _parseDate(json['createdAt']),
      submittedAt: _parseDate(json['submittedAt']),
      decidedAt: _parseDate(json['decidedAt']),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool get isPublished => status == 'PUBLISHED';
  bool get isRejected => status == 'REJECTED';
  bool get isDraft => status == 'DRAFT';
  bool get isPending => status == 'PENDING';
}

/// Combined model used by the unified list screen.
class UnifiedChangeRequest {
  final String id;
  final String kind; // 'CHARGING' or 'BATTERY_SWAP'
  final String type;
  final String status;
  final String? displayName;
  final int? riskScore;
  final String? adminNote;
  final DateTime? createdAt;

  const UnifiedChangeRequest({
    required this.id,
    required this.kind,
    required this.type,
    required this.status,
    this.displayName,
    this.riskScore,
    this.adminNote,
    this.createdAt,
  });

  factory UnifiedChangeRequest.fromCharging(ChangeRequestItem cr) {
    return UnifiedChangeRequest(
      id: cr.id,
      kind: 'CHARGING',
      type: cr.type,
      status: cr.status,
      displayName: cr.stationName,
      riskScore: cr.riskScore,
      adminNote: cr.adminNote,
      createdAt: cr.createdAt,
    );
  }

  factory UnifiedChangeRequest.fromBatterySwap(BatterySwapChangeRequestItem cr) {
    final desc = cr.operatingHours != null
        ? 'Batteries: ${cr.totalBatteries ?? '-'} • Power: ${cr.avgChargePowerKw?.toStringAsFixed(1) ?? '-'} kW'
        : null;
    return UnifiedChangeRequest(
      id: cr.id,
      kind: 'BATTERY_SWAP',
      type: cr.type,
      status: cr.status,
      displayName: desc,
      riskScore: cr.riskScore,
      adminNote: cr.adminNote,
      createdAt: cr.createdAt,
    );
  }
}
