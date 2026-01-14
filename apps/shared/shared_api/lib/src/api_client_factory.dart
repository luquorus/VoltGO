import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';

/// API Client Factory
/// 
/// Creates configured Dio instances with:
/// - Base URL from environment
/// - Auth interceptor attached
/// - Error interceptor attached
/// 
/// Exposes typed API clients for each namespace:
/// - Auth: /auth/**
/// - EV User Mobile: /api/ev/**
/// - Collaborator Mobile: /api/collab/mobile/**
/// - Collaborator Web: /api/collab/web/**
/// - Admin Web: /api/admin/**
class ApiClientFactory {
  final Dio dio;
  final Ref ref;

  ApiClientFactory({
    required this.dio,
    required this.ref,
  });

  /// Create factory from base URL
  /// 
  /// Reads baseUrl from environment or uses default
  static ApiClientFactory create(Ref ref, {String? baseUrl}) {
    final url = baseUrl ?? 
        const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
    
    final dio = ref.read(dioClientProvider(url));
    
    // Attach auth interceptor
    dio.interceptors.add(AuthInterceptor(ref));
    
    return ApiClientFactory(dio: dio, ref: ref);
  }

  /// Get Dio instance for custom API calls
  Dio get client => dio;

  // ============================================
  // Typed API Clients
  // ============================================

  /// Authentication API
  /// Endpoints: /auth/**
  AuthApiClient get auth => AuthApiClient(dio);

  /// EV User Mobile API
  /// Endpoints: /api/ev/**
  EvUserMobileApiClient get ev => EvUserMobileApiClient(dio);

  /// Collaborator Mobile API
  /// Endpoints: /api/collab/mobile/**
  CollaboratorMobileApiClient get collabMobile => CollaboratorMobileApiClient(dio);

  /// Collaborator Web API
  /// Endpoints: /api/collab/web/**
  CollaboratorWebApiClient get collabWeb => CollaboratorWebApiClient(dio);

  /// Admin Web API
  /// Endpoints: /api/admin/**
  AdminWebApiClient get admin => AdminWebApiClient(dio);
}

/// Provider for ApiClientFactory
final apiClientFactoryProvider = StateProvider<ApiClientFactory?>((ref) => null);

// ============================================
// API Client Wrappers
// ============================================

/// Base API client with error handling
abstract class BaseApiClient {
  final Dio dio;

  BaseApiClient(this.dio);

  /// Handle API response, throw ApiError for non-2xx
  Future<T> _handleResponse<T>(Future<Response> request) async {
    try {
      final response = await request;
      
      // Handle 204 No Content (common for DELETE requests)
      // When status is 204 or data is null, return null for void types
      if (response.statusCode == 204 || response.data == null) {
        // For void return type (Future<void>), we can safely return null
        // This is handled by the type system - void functions can return null
        return null as T;
      }
      
      return response.data as T;
    } on DioException catch (e) {
      // ErrorInterceptor already maps to ApiError, check error field
      if (e.error is ApiError) {
        throw e.error as ApiError;
      }
      // Fallback: try parsing response data
      if (e.response != null && e.response!.data is Map) {
        throw ApiError.fromJson(e.response!.data as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.get(path, queryParameters: queryParameters));
  }

  Future<T> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.post(path, data: data, queryParameters: queryParameters));
  }

  Future<T> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.put(path, data: data, queryParameters: queryParameters));
  }

  Future<T> delete<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.delete(path, queryParameters: queryParameters));
  }
}

/// Authentication API Client
/// Endpoints: /auth/**
class AuthApiClient extends BaseApiClient {
  AuthApiClient(super.dio);

  /// POST /auth/register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role,
  }) {
    return post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'role': role,
      },
    );
  }

  /// POST /auth/login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
  }
}

/// EV User Mobile API Client
/// Endpoints: /api/ev/**
class EvUserMobileApiClient extends BaseApiClient {
  EvUserMobileApiClient(super.dio);

  /// GET /api/ev/stations
  Future<Map<String, dynamic>> getStations({
    required double lat,
    required double lng,
    required double radiusKm,
    double? minPowerKw,
    bool? hasAC,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/stations',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        if (minPowerKw != null) 'minPowerKw': minPowerKw,
        if (hasAC != null) 'hasAC': hasAC,
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/ev/stations/{stationId}
  Future<Map<String, dynamic>> getStation(String stationId) {
    return get<Map<String, dynamic>>('/api/ev/stations/$stationId');
  }

  /// GET /api/ev/stations/{stationId}/charger-units
  Future<List<dynamic>> getChargerUnits(String stationId) {
    return get<List<dynamic>>('/api/ev/stations/$stationId/charger-units');
  }

  /// GET /api/ev/stations/{stationId}/availability
  Future<Map<String, dynamic>> getAvailability({
    required String stationId,
    required String date, // YYYY-MM-DD
    String tz = 'Asia/Bangkok',
    int slotMinutes = 30,
    String? powerType,
    double? minPowerKw,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/stations/$stationId/availability',
      queryParameters: {
        'date': date,
        'tz': tz,
        'slotMinutes': slotMinutes,
        if (powerType != null) 'powerType': powerType,
        if (minPowerKw != null) 'minPowerKw': minPowerKw,
      },
    );
  }

  /// GET /api/ev/stations/search/by-name?name=...
  Future<Map<String, dynamic>> searchStationsByName({
    required String name,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/stations/search/by-name',
      queryParameters: {
        'name': name,
        'page': page,
        'size': size,
      },
    );
  }

  // ============================================
  // Booking Endpoints
  // ============================================

  /// POST /api/ev/bookings
  Future<Map<String, dynamic>> createBooking({
    required String stationId,
    required String chargerUnitId,
    required String startTime,
    required String endTime,
  }) {
    return post<Map<String, dynamic>>(
      '/api/ev/bookings',
      data: {
        'stationId': stationId,
        'chargerUnitId': chargerUnitId,
        'startTime': startTime,
        'endTime': endTime,
      },
    );
  }

  /// GET /api/ev/bookings/mine
  Future<Map<String, dynamic>> getBookings({
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/bookings/mine',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/ev/bookings/{id}
  Future<Map<String, dynamic>> getBooking(String id) {
    return get<Map<String, dynamic>>('/api/ev/bookings/$id');
  }

  /// POST /api/ev/bookings/{id}/cancel
  Future<Map<String, dynamic>> cancelBooking(String id) {
    return post<Map<String, dynamic>>('/api/ev/bookings/$id/cancel');
  }

  // ============================================
  // Payment Endpoints
  // ============================================

  /// POST /api/ev/bookings/{bookingId}/payment-intent
  Future<Map<String, dynamic>> createPaymentIntent(String bookingId) {
    return post<Map<String, dynamic>>('/api/ev/bookings/$bookingId/payment-intent');
  }

  /// POST /api/ev/payments/{intentId}/simulate-success
  Future<Map<String, dynamic>> simulatePaymentSuccess(String intentId) {
    return post<Map<String, dynamic>>('/api/ev/payments/$intentId/simulate-success');
  }

  /// POST /api/ev/payments/{intentId}/simulate-fail
  Future<Map<String, dynamic>> simulatePaymentFail(String intentId) {
    return post<Map<String, dynamic>>('/api/ev/payments/$intentId/simulate-fail');
  }

  // ============================================
  // Change Request Endpoints
  // ============================================

  /// POST /api/ev/change-requests
  Future<Map<String, dynamic>> createChangeRequest(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/ev/change-requests', data: data);
  }

  /// GET /api/ev/change-requests/mine
  Future<List<dynamic>> getChangeRequests() {
    return get<List<dynamic>>('/api/ev/change-requests/mine');
  }

  /// GET /api/ev/change-requests/{id}
  Future<Map<String, dynamic>> getChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/ev/change-requests/$id');
  }

  /// POST /api/ev/change-requests/{id}/submit
  Future<Map<String, dynamic>> submitChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/ev/change-requests/$id/submit');
  }

  /// PUT /api/ev/change-requests/{id}
  Future<Map<String, dynamic>> updateChangeRequest(String id, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>('/api/ev/change-requests/$id', data: data);
  }

  // ============================================
  // File Upload Endpoints
  // ============================================

  /// POST /api/ev/files/presign-upload
  Future<Map<String, dynamic>> presignUpload({String? contentType}) {
    return post<Map<String, dynamic>>(
      '/api/ev/files/presign-upload',
      data: contentType != null ? {'contentType': contentType} : null,
    );
  }

  /// GET /api/ev/files/presign-view?objectKey=...
  Future<Map<String, dynamic>> presignView(String objectKey, {int expiresInMinutes = 60}) {
    return get<Map<String, dynamic>>(
      '/api/ev/files/presign-view',
      queryParameters: {
        'objectKey': objectKey,
        'expiresInMinutes': expiresInMinutes,
      },
    );
  }

  // ============================================
  // Issue Endpoints
  // ============================================

  /// POST /api/ev/stations/{stationId}/issues
  Future<Map<String, dynamic>> reportIssue({
    required String stationId,
    required String category,
    required String description,
  }) {
    return post<Map<String, dynamic>>(
      '/api/ev/stations/$stationId/issues',
      data: {
        'category': category,
        'description': description,
      },
    );
  }

  /// GET /api/ev/issues/mine
  Future<List<dynamic>> getMyIssues() {
    return get<List<dynamic>>('/api/ev/issues/mine');
  }
}

/// Collaborator Mobile API Client
/// Endpoints: /api/collab/mobile/**
class CollaboratorMobileApiClient extends BaseApiClient {
  CollaboratorMobileApiClient(super.dio);

  /// GET /api/collab/mobile/tasks
  Future<List<dynamic>> getTasks({List<String>? status}) {
    return get<List<dynamic>>(
      '/api/collab/mobile/tasks',
      queryParameters: status != null ? {'status': status} : null,
    );
  }

  /// POST /api/collab/mobile/tasks/{id}/check-in
  Future<Map<String, dynamic>> checkIn({
    required String taskId,
    required double lat,
    required double lng,
    String? deviceNote,
  }) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/tasks/$taskId/check-in',
      data: {
        'lat': lat,
        'lng': lng,
        if (deviceNote != null) 'deviceNote': deviceNote,
      },
    );
  }

  /// POST /api/collab/mobile/files/presign-upload
  Future<Map<String, dynamic>> presignUpload({String? contentType}) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/files/presign-upload',
      data: contentType != null ? {'contentType': contentType} : <String, dynamic>{},
    );
  }

  /// POST /api/collab/mobile/tasks/{id}/submit-evidence
  Future<Map<String, dynamic>> submitEvidence({
    required String taskId,
    required String photoObjectKey,
    String? note,
  }) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/tasks/$taskId/submit-evidence',
      data: {
        'photoObjectKey': photoObjectKey,
        if (note != null) 'note': note,
      },
    );
  }

  /// PUT /api/collab/mobile/me/location
  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lng,
    String? sourceNote,
  }) {
    return put<Map<String, dynamic>>(
      '/api/collab/mobile/me/location',
      data: {
        'lat': lat,
        'lng': lng,
        if (sourceNote != null) 'sourceNote': sourceNote,
      },
    );
  }
}

/// Collaborator Web API Client
/// Endpoints: /api/collab/web/**
class CollaboratorWebApiClient extends BaseApiClient {
  CollaboratorWebApiClient(super.dio);

  /// GET /api/collab/web/tasks
  Future<Map<String, dynamic>> getTasks({
    String? status,
    int? priority,
    String? slaDueBefore,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/web/tasks',
      queryParameters: {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (slaDueBefore != null) 'slaDueBefore': slaDueBefore,
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/collab/web/tasks/history
  Future<Map<String, dynamic>> getTaskHistory({
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/web/tasks/history',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/collab/web/tasks/kpi
  Future<Map<String, dynamic>> getKpi() {
    return get<Map<String, dynamic>>('/api/collab/web/tasks/kpi');
  }

  /// GET /api/collab/web/me/profile
  Future<Map<String, dynamic>> getProfile() {
    return get<Map<String, dynamic>>('/api/collab/web/me/profile');
  }

  /// GET /api/collab/web/me/contracts
  Future<List<dynamic>> getContracts() {
    return get<List<dynamic>>('/api/collab/web/me/contracts');
  }

  /// GET /api/collab/web/files/presign-view
  Future<Map<String, dynamic>> presignView({
    required String objectKey,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/web/files/presign-view',
      queryParameters: {
        'objectKey': objectKey,
      },
    );
  }

  /// PUT /api/collab/web/me/location
  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lng,
    String? sourceNote,
  }) {
    return put<Map<String, dynamic>>(
      '/api/collab/web/me/location',
      data: {
        'lat': lat,
        'lng': lng,
        if (sourceNote != null) 'sourceNote': sourceNote,
      },
    );
  }
}

/// Admin Web API Client
/// Endpoints: /api/admin/**
class AdminWebApiClient extends BaseApiClient {
  AdminWebApiClient(super.dio);

  /// GET /api/admin/change-requests
  Future<List<dynamic>> getChangeRequests({String? status}) {
    return get<List<dynamic>>(
      '/api/admin/change-requests',
      queryParameters: status != null ? {'status': status} : null,
    );
  }

  /// GET /api/admin/change-requests/{id}
  Future<Map<String, dynamic>> getChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/admin/change-requests/$id');
  }

  /// POST /api/admin/change-requests/{id}/approve
  Future<Map<String, dynamic>> approveChangeRequest(String id, {String? note}) {
    return post<Map<String, dynamic>>(
      '/api/admin/change-requests/$id/approve',
      data: note != null ? {'note': note} : null,
    );
  }

  /// POST /api/admin/change-requests/{id}/reject
  Future<Map<String, dynamic>> rejectChangeRequest(String id, {required String reason}) {
    return post<Map<String, dynamic>>(
      '/api/admin/change-requests/$id/reject',
      data: {'reason': reason},
    );
  }

  /// POST /api/admin/change-requests/{id}/publish
  Future<Map<String, dynamic>> publishChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/admin/change-requests/$id/publish');
  }

  // ============================================
  // Verification Tasks Endpoints
  // ============================================

  /// POST /api/admin/verification-tasks
  Future<Map<String, dynamic>> createVerificationTask({
    required String stationId,
    String? changeRequestId,
    int? priority,
    String? slaDueAt, // ISO 8601 string
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/verification-tasks',
      data: {
        'stationId': stationId,
        if (changeRequestId != null) 'changeRequestId': changeRequestId,
        if (priority != null) 'priority': priority,
        if (slaDueAt != null) 'slaDueAt': slaDueAt,
      },
    );
  }

  /// GET /api/admin/verification-tasks
  Future<Map<String, dynamic>> getVerificationTasks({
    String? status,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/verification-tasks',
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/admin/verification-tasks/{id}
  Future<Map<String, dynamic>> getVerificationTask(String id) {
    return get<Map<String, dynamic>>('/api/admin/verification-tasks/$id');
  }

  /// POST /api/admin/verification-tasks/{id}/assign
  Future<Map<String, dynamic>> assignVerificationTask({
    required String id,
    String? collaboratorUserId,
    String? collaboratorEmail,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/verification-tasks/$id/assign',
      data: {
        if (collaboratorUserId != null) 'collaboratorUserId': collaboratorUserId,
        if (collaboratorEmail != null) 'collaboratorEmail': collaboratorEmail,
      },
    );
  }

  /// GET /api/admin/verification-tasks/{id}/collaborator-candidates
  Future<Map<String, dynamic>> getCollaboratorCandidates({
    required String taskId,
    bool onlyActiveContract = true,
    bool includeUnlocated = false,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/verification-tasks/$taskId/collaborator-candidates',
      queryParameters: {
        'onlyActiveContract': onlyActiveContract,
        'includeUnlocated': includeUnlocated,
        'page': page,
        'size': size,
      },
    );
  }

  /// POST /api/admin/verification-tasks/{id}/review
  Future<Map<String, dynamic>> reviewVerificationTask({
    required String id,
    required String result, // PASS or FAIL
    String? adminNote,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/verification-tasks/$id/review',
      data: {
        'result': result,
        if (adminNote != null) 'adminNote': adminNote,
      },
    );
  }

  // ============================================
  // Issues Management Endpoints
  // ============================================

  /// GET /api/admin/issues?status=
  Future<List<dynamic>> getIssues({String? status}) {
    return get<List<dynamic>>(
      '/api/admin/issues',
      queryParameters: status != null ? {'status': status} : null,
    );
  }

  /// GET /api/admin/issues/{id}
  Future<Map<String, dynamic>> getIssue(String id) {
    return get<Map<String, dynamic>>('/api/admin/issues/$id');
  }

  /// POST /api/admin/issues/{id}/acknowledge
  Future<Map<String, dynamic>> acknowledgeIssue(String id) {
    return post<Map<String, dynamic>>('/api/admin/issues/$id/acknowledge');
  }

  /// POST /api/admin/issues/{id}/resolve
  Future<Map<String, dynamic>> resolveIssue(String id, {required String note}) {
    return post<Map<String, dynamic>>(
      '/api/admin/issues/$id/resolve',
      data: {'note': note},
    );
  }

  /// POST /api/admin/issues/{id}/reject
  Future<Map<String, dynamic>> rejectIssue(String id, {required String note}) {
    return post<Map<String, dynamic>>(
      '/api/admin/issues/$id/reject',
      data: {'note': note},
    );
  }

  // ============================================
  // Files Endpoints
  // ============================================

  /// GET /api/admin/files/presign-view?objectKey=
  Future<Map<String, dynamic>> presignView({required String objectKey}) {
    return get<Map<String, dynamic>>(
      '/api/admin/files/presign-view',
      queryParameters: {
        'objectKey': objectKey,
      },
    );
  }

  // ============================================
  // Station Trust Endpoints
  // ============================================

  /// GET /api/admin/stations/{stationId}/trust
  Future<Map<String, dynamic>> getStationTrust(String stationId) {
    return get<Map<String, dynamic>>('/api/admin/stations/$stationId/trust');
  }

  /// POST /api/admin/stations/{stationId}/trust/recalculate
  Future<Map<String, dynamic>> recalculateStationTrust(String stationId) {
    return post<Map<String, dynamic>>('/api/admin/stations/$stationId/trust/recalculate');
  }

  // ============================================
  // Audit Logs Endpoints
  // ============================================

  /// GET /api/admin/audit
  /// Query audit logs with optional filters: entityType, entityId, from, to, page, size
  Future<Map<String, dynamic>> queryAuditLogs({
    String? entityType,
    String? entityId,
    String? from, // ISO 8601 date-time string
    String? to, // ISO 8601 date-time string
    int page = 0,
    int size = 20,
  }) {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (entityType != null && entityType.isNotEmpty) {
      queryParams['entityType'] = entityType;
    }
    if (entityId != null && entityId.isNotEmpty) {
      queryParams['entityId'] = entityId;
    }
    if (from != null && from.isNotEmpty) {
      queryParams['from'] = from;
    }
    if (to != null && to.isNotEmpty) {
      queryParams['to'] = to;
    }
    return get<Map<String, dynamic>>(
      '/api/admin/audit',
      queryParameters: queryParams,
    );
  }

  /// GET /api/admin/stations/{stationId}/audit
  Future<List<dynamic>> getStationAuditLogs(String stationId) {
    return get<List<dynamic>>('/api/admin/stations/$stationId/audit');
  }

  /// GET /api/admin/change-requests/{id}/audit
  Future<List<dynamic>> getChangeRequestAuditLogs(String changeRequestId) {
    return get<List<dynamic>>('/api/admin/change-requests/$changeRequestId/audit');
  }

  // ============================================
  // Collaborator Management Endpoints
  // ============================================

  /// POST /api/admin/collaborators
  /// Create a collaborator profile for a user account with COLLABORATOR role
  Future<Map<String, dynamic>> createCollaborator({
    required String userAccountId,
    String? fullName,
    String? phone,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/collaborators',
      data: {
        'userAccountId': userAccountId,
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
      },
    );
  }

  /// GET /api/admin/collaborators
  /// Get all collaborator profiles with pagination
  Future<Map<String, dynamic>> getCollaborators({
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/collaborators',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/admin/collaborators/{id}
  /// Get a specific collaborator profile by ID
  Future<Map<String, dynamic>> getCollaborator(String id) {
    return get<Map<String, dynamic>>('/api/admin/collaborators/$id');
  }

  // ============================================
  // Contract Management Endpoints
  // ============================================

  /// POST /api/admin/contracts
  /// Create a new contract for a collaborator
  Future<Map<String, dynamic>> createContract(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/admin/contracts', data: data);
  }

  /// GET /api/admin/contracts?collaboratorId=...
  /// Get all contracts for a specific collaborator
  Future<List<dynamic>> getContracts({required String collaboratorId}) {
    return get<List<dynamic>>(
      '/api/admin/contracts',
      queryParameters: {'collaboratorId': collaboratorId},
    );
  }

  /// GET /api/admin/contracts/{id}
  /// Get a specific contract by ID
  Future<Map<String, dynamic>> getContract(String id) {
    return get<Map<String, dynamic>>('/api/admin/contracts/$id');
  }

  /// PUT /api/admin/contracts/{id}
  /// Update contract dates, region, or note
  Future<Map<String, dynamic>> updateContract(String id, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>('/api/admin/contracts/$id', data: data);
  }

  /// POST /api/admin/contracts/{id}/terminate
  /// Terminate an active contract
  Future<Map<String, dynamic>> terminateContract(String id, {String? reason}) {
    return post<Map<String, dynamic>>(
      '/api/admin/contracts/$id/terminate',
      data: reason != null ? {'reason': reason} : null,
    );
  }

  // ============================================
  // Station Management Endpoints
  // ============================================

  /// GET /api/admin/stations
  /// Get all stations with pagination
  Future<Map<String, dynamic>> getStations({
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/stations',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/admin/stations/{id}
  /// Get station detail by ID
  Future<Map<String, dynamic>> getStation(String id) {
    return get<Map<String, dynamic>>('/api/admin/stations/$id');
  }

  /// POST /api/admin/stations
  /// Create a new station
  Future<Map<String, dynamic>> createStation(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/admin/stations', data: data);
  }

  /// POST /api/admin/stations/import-csv
  /// Import stations from CSV file
  Future<Map<String, dynamic>> importStationsFromCsv(dynamic file) {
    // This will be handled by the frontend using FormData directly
    throw UnimplementedError('Use FormData with dio client directly');
  }

  /// PUT /api/admin/stations/{id}
  /// Update a station
  Future<Map<String, dynamic>> updateStation(String id, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>('/api/admin/stations/$id', data: data);
  }

  /// DELETE /api/admin/stations/{id}
  /// Delete (archive) a station
  Future<void> deleteStation(String id) {
    return delete<void>('/api/admin/stations/$id');
  }
}

