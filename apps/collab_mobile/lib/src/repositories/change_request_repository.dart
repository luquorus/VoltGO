import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

/// Repository for Charging-Station Change Requests submitted by collaborators.
///
/// Mirrors `ChangeRequestRepository` in `ev_user_mobile` but routes through
/// `CollaboratorMobileApiClient` (which targets `/api/collab/mobile/change-requests/**`).
/// The list returned by the backend contains the full `ChangeRequestResponseDTO`
/// for each CR, so the UI can render every field the same way it does for EV users.
class ChangeRequestRepository {
  final CollaboratorMobileApiClient apiClient;

  ChangeRequestRepository(this.apiClient);

  ApiError _wrap(Object error, {String? fallbackMessage}) {
    if (error is ApiError) return error;
    return ApiError(
      traceId: '',
      code: 'UNKNOWN_ERROR',
      message: fallbackMessage ?? error.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// Get all charging-station change requests owned by the current collaborator.
  Future<List<ChangeRequestItem>> getMyChangeRequests() async {
    try {
      final response = await apiClient.getMyChangeRequests();
      return response
          .map((json) => ChangeRequestItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load change requests.');
    }
  }

  /// Get full detail of a single charging-station change request.
  Future<ChangeRequestItem> getChangeRequest(String id) async {
    try {
      final response = await apiClient.getChangeRequest(id);
      return ChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load change request detail.');
    }
  }

  /// Create a DRAFT charging-station change request.
  Future<ChangeRequestItem> createChangeRequest(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.createChangeRequest(data);
      return ChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Failed to create change request.');
    }
  }

  /// Submit a DRAFT charging-station change request for admin review.
  Future<ChangeRequestItem> submitChangeRequest(String id) async {
    try {
      final response = await apiClient.submitChangeRequest(id);
      return ChangeRequestItem.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Failed to submit change request.');
    }
  }
}

/// Lightweight value object representing a single charging-station CR in the list.
class ChangeRequestItem {
  final String id;
  final String type; // CREATE_STATION, UPDATE_STATION
  final String status; // DRAFT, PENDING, APPROVED, REJECTED, PUBLISHED
  final String? stationId;
  final String? stationName;
  final int? riskScore;
  final String? riskLevel;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  const ChangeRequestItem({
    required this.id,
    required this.type,
    required this.status,
    this.stationId,
    this.stationName,
    this.riskScore,
    this.riskLevel,
    this.adminNote,
    this.createdAt,
    this.submittedAt,
    this.decidedAt,
  });

  factory ChangeRequestItem.fromJson(Map<String, dynamic> json) {
    return ChangeRequestItem(
      id: json['id'] as String,
      type: (json['type'] ?? 'UPDATE_STATION') as String,
      status: (json['status'] ?? 'DRAFT') as String,
      stationId: json['stationId'] as String?,
      stationName: _extractStationName(json),
      riskScore: (json['riskScore'] as num?)?.toInt(),
      riskLevel: json['riskLevel'] as String?,
      adminNote: json['adminNote'] as String?,
      createdAt: _parseDate(json['createdAt']),
      submittedAt: _parseDate(json['submittedAt']),
      decidedAt: _parseDate(json['decidedAt']),
    );
  }

  static String? _extractStationName(Map<String, dynamic> json) {
    // The DTO may nest station data under stationData; fall back to top-level.
    final data = json['stationData'] as Map<String, dynamic>?;
    if (data != null && data['name'] is String) {
      return data['name'] as String;
    }
    return json['stationName'] as String?;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  bool get isCharging => type == 'CREATE_STATION' || type == 'UPDATE_STATION';
  bool get isPublished => status == 'PUBLISHED';
  bool get isRejected => status == 'REJECTED';
  bool get isDraft => status == 'DRAFT';
  bool get isPending => status == 'PENDING';
}
