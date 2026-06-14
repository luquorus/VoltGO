import 'dart:typed_data';
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
  /// Reads baseUrl from environment or uses default. When [onUnauthorized]
  /// is provided, it is invoked whenever the server responds with 401 so the
  /// host app can clear local credentials and bounce the user to /login.
  static ApiClientFactory create(
    Ref ref, {
    String? baseUrl,
    void Function()? onUnauthorized,
  }) {
    final url = baseUrl ??
        const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

    final dio = ref.read(dioClientProvider(url));

    // Replace the placeholder ErrorInterceptor with one wired to the
    // caller's onUnauthorized callback (so 401s trigger a session wipe).
    dio.interceptors.removeWhere((i) => i is ErrorInterceptor);
    dio.interceptors.add(ErrorInterceptor(onUnauthorized: onUnauthorized));

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

  /// Public API
  /// Endpoints: /api/public/** (no auth)
  PublicApiClient get public => PublicApiClient(dio);
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

  /// Expose Dio instance for direct access (e.g. DELETE calls not wrapped by typed methods).
  Dio get client => dio;

  /// Handle API response, throw ApiError for non-2xx
  Future<T> _handleResponse<T>(Future<Response> request) async {
    try {
      final response = await request;
      
      // Handle 204 No Content (common for DELETE requests)
      // When status is 204 or data is null, return null for void types
      if (response.statusCode == 204 || response.data == null) {
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

  Future<T> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.patch(path, data: data, queryParameters: queryParameters));
  }

  Future<T> delete<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _handleResponse<T>(dio.delete(path, queryParameters: queryParameters));
  }

  /// Download binary data (e.g., images) via GET request.
  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await dio.get<List<int>>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
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
    String? referralCode,
  }) {
    return post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'role': role,
        if (referralCode != null && referralCode.isNotEmpty) 'referralCode': referralCode,
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
  // AI Recommendation Endpoints
  // ============================================

  /// POST /api/ev/ai/personalized-recommendations
  Future<Map<String, dynamic>> getPersonalizedRecommendations({
    required Map<String, dynamic> request,
  }) {
    return post<Map<String, dynamic>>(
      '/api/ev/ai/personalized-recommendations',
      data: request,
    );
  }

  /// POST /api/ev/ai/smart-time-suggestions
  Future<Map<String, dynamic>> getSmartTimeSuggestions({
    required String stationId,
    required double distanceKm,
    required int batteryPercent,
    required int targetPercent,
    required double batteryCapacityKwh,
    double? averageSpeedKmph,
  }) {
    return post<Map<String, dynamic>>(
      '/api/ev/ai/smart-time-suggestions',
      data: {
        'stationId': stationId,
        'distanceKm': distanceKm,
        'batteryPercent': batteryPercent,
        'targetPercent': targetPercent,
        'batteryCapacityKwh': batteryCapacityKwh,
        if (averageSpeedKmph != null) 'averageSpeedKmph': averageSpeedKmph,
      },
    );
  }

  // ============================================
  // Battery Swap Simulation Endpoints
  // ============================================

  /// GET /api/ev/battery-swap/stations
  Future<List<dynamic>> getBatterySwapStations({
    required double lat,
    required double lng,
    double radiusKm = 15,
  }) {
    return get<List<dynamic>>(
      '/api/ev/battery-swap/stations',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
      },
    );
  }

  /// GET /api/ev/battery-swap/stations/{stationId}
  Future<Map<String, dynamic>> getBatterySwapStationDetail(String stationId) {
    return get<Map<String, dynamic>>('/api/ev/battery-swap/stations/$stationId');
  }

  /// Search battery swap stations by name (uses nearby search + client-side filter).
  /// Falls back to a wide-radius query to capture all published stations.
  Future<List<Map<String, dynamic>>> searchBatterySwapStationsByName({
    required String name,
    required double lat,
    required double lng,
    double radiusKm = 50,
  }) async {
    final results = await getBatterySwapStations(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );
    final lowerName = name.toLowerCase();
    return (results as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .where((s) {
          final stationName = s['name'] as String? ?? '';
          final address = s['address'] as String? ?? '';
          return stationName.toLowerCase().contains(lowerName) ||
              address.toLowerCase().contains(lowerName);
        })
        .toList();
  }

  /// POST /api/ev/battery-swap/reservations
  Future<Map<String, dynamic>> reserveBatterySwap({
    required String stationId,
    required DateTime expectedArrivalAt,
    int? requestedBatteryPercent,
    double? batteryCapacityKwh,
    String? pileId,
    String? slotId,
    String? note,
  }) {
    return post<Map<String, dynamic>>(
      '/api/ev/battery-swap/reservations',
      data: {
        'stationId': stationId,
        'expectedArrivalAt': expectedArrivalAt.toUtc().toIso8601String(),
        if (requestedBatteryPercent != null) 'requestedBatteryPercent': requestedBatteryPercent,
        if (batteryCapacityKwh != null) 'batteryCapacityKwh': batteryCapacityKwh,
        if (pileId != null) 'pileId': pileId,
        if (slotId != null) 'slotId': slotId,
        if (note != null) 'note': note,
      },
    );
  }

  /// POST /api/ev/battery-swap/reservations/{id}/confirm-arrival
  Future<Map<String, dynamic>> confirmArrivalBatterySwap(String reservationId) {
    return post<Map<String, dynamic>>(
        '/api/ev/battery-swap/reservations/$reservationId/confirm-arrival');
  }

  /// POST /api/ev/battery-swap/reservations/{id}/start
  Future<Map<String, dynamic>> startBatterySwap(String reservationId) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap/reservations/$reservationId/start');
  }

  /// POST /api/ev/battery-swap/reservations/{id}/confirm
  Future<Map<String, dynamic>> confirmBatterySwap(String reservationId) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap/reservations/$reservationId/confirm');
  }

  /// POST /api/ev/battery-swap/reservations/{id}/cancel
  Future<Map<String, dynamic>> cancelBatterySwap(String reservationId) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap/reservations/$reservationId/cancel');
  }

  /// POST /api/ev/battery-swap/reservations/{id}/pay
  Future<Map<String, dynamic>> payBatterySwap(String reservationId) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap/reservations/$reservationId/pay');
  }

  /// GET /api/ev/battery-swap/reservations/mine
  Future<List<dynamic>> getMyBatterySwapReservations() {
    return get<List<dynamic>>('/api/ev/battery-swap/reservations/mine');
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
  // Battery Swap Change Request Endpoints
  // ============================================

  /// POST /api/ev/battery-swap-change-requests
  Future<Map<String, dynamic>> createBatterySwapChangeRequest(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap-change-requests', data: data);
  }

  /// GET /api/ev/battery-swap-change-requests
  Future<List<dynamic>> getBatterySwapChangeRequests() {
    return get<List<dynamic>>('/api/ev/battery-swap-change-requests');
  }

  /// GET /api/ev/battery-swap-change-requests/{id}
  Future<Map<String, dynamic>> getBatterySwapChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/ev/battery-swap-change-requests/$id');
  }

  /// POST /api/ev/battery-swap-change-requests/{id}/submit
  Future<Map<String, dynamic>> submitBatterySwapChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/ev/battery-swap-change-requests/$id/submit');
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

  // ============================================
  // Notification Endpoints
  // ============================================

  /// GET /api/ev/notifications
  /// Get paginated list of notifications with optional filters
  Future<Map<String, dynamic>> getNotifications({
    String? category,
    bool? isRead,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/notifications',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (isRead != null) 'isRead': isRead.toString(),
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/ev/notifications/unread-count
  /// Get count of unread notifications
  Future<int> getUnreadNotificationCount() async {
    final response = await dio.get('/api/ev/notifications/unread-count');
    return response.data as int;
  }

  /// PATCH /api/ev/notifications/{id}/read
  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) {
    return patch<void>('/api/ev/notifications/$notificationId/read');
  }

  /// PATCH /api/ev/notifications/read-all
  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() {
    return patch<void>('/api/ev/notifications/read-all');
  }

  // ============================================
  // Loyalty Point System Endpoints
  // ============================================

  /// GET /api/ev/loyalty/me
  /// Get current user's loyalty profile
  Future<Map<String, dynamic>> getLoyaltyProfile() {
    return get<Map<String, dynamic>>('/api/ev/loyalty/me');
  }

  /// GET /api/ev/loyalty/points/history
  /// Get paginated point transaction history
  Future<Map<String, dynamic>> getPointHistory({int page = 0, int size = 20}) {
    return get<Map<String, dynamic>>(
      '/api/ev/loyalty/points/history',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/ev/loyalty/ratings/eligible
  /// Get stations eligible for rating
  Future<List<dynamic>> getEligibleStationsForRating() {
    return get<List<dynamic>>('/api/ev/loyalty/ratings/eligible');
  }

  /// GET /api/ev/loyalty/ratings
  /// Get current user's ratings
  Future<List<dynamic>> getMyRatings() {
    return get<List<dynamic>>('/api/ev/loyalty/ratings');
  }

  /// POST /api/ev/loyalty/ratings
  /// Submit a station rating
  Future<Map<String, dynamic>> submitRating(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/ev/loyalty/ratings', data: data);
  }

  /// POST /api/ev/loyalty/ratings/{id}/helpful
  /// Mark a rating as helpful
  Future<void> markRatingHelpful(String ratingId) {
    return post<void>('/api/ev/loyalty/ratings/$ratingId/helpful');
  }

  /// GET /api/ev/loyalty/badges
  /// Get current user's earned badges
  Future<List<dynamic>> getMyBadges() {
    return get<List<dynamic>>('/api/ev/loyalty/badges');
  }

  /// GET /api/ev/loyalty/badges/available
  /// Get all badges with progress
  Future<List<dynamic>> getAvailableBadges() {
    return get<List<dynamic>>('/api/ev/loyalty/badges/available');
  }

  /// POST /api/ev/loyalty/referral/generate
  /// Generate a referral code
  Future<Map<String, dynamic>> generateReferralCode() {
    return post<Map<String, dynamic>>('/api/ev/loyalty/referral/generate');
  }

  // ============================================
  // Public Loyalty Endpoints
  // ============================================

  /// GET /api/ev/loyalty/public/stations/{stationId}/ratings
  /// Get public ratings for a station
  Future<Map<String, dynamic>> getStationRatings(
    String stationId, {
    int page = 0,
    int size = 10,
  }) {
    return get<Map<String, dynamic>>(
      '/api/ev/loyalty/public/stations/$stationId/ratings',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/ev/loyalty/public/stations/{stationId}/summary
  /// Get rating summary for a station
  Future<Map<String, dynamic>> getStationRatingSummary(String stationId) {
    return get<Map<String, dynamic>>(
      '/api/ev/loyalty/public/stations/$stationId/summary',
    );
  }

  // ============================================
  // Voucher Redemption Endpoints
  // ============================================

  /// GET /api/ev/loyalty/vouchers
  /// Get available vouchers to redeem
  Future<List<dynamic>> getAvailableVouchers() {
    return get<List<dynamic>>('/api/ev/loyalty/vouchers');
  }

  /// GET /api/ev/loyalty/vouchers/mine?status=&page=&size=
  /// Get user's redeemed vouchers (backend returns Spring Page object)
  Future<Map<String, dynamic>> getMyVouchers({String? status, int page = 0, int size = 20}) {
    return get<Map<String, dynamic>>(
      '/api/ev/loyalty/vouchers/mine',
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'size': size,
      },
    );
  }

  /// POST /api/ev/loyalty/vouchers/{definitionId}/redeem
  /// Redeem a voucher definition
  Future<Map<String, dynamic>> redeemVoucher(String definitionId) {
    return post<Map<String, dynamic>>('/api/ev/loyalty/vouchers/$definitionId/redeem');
  }

  /// GET /api/ev/loyalty/vouchers/redemptions/{redemptionId}
  /// Get voucher redemption detail
  Future<Map<String, dynamic>> getVoucherRedemptionDetail(String redemptionId) {
    return get<Map<String, dynamic>>('/api/ev/loyalty/vouchers/redemptions/$redemptionId');
  }

  /// POST /api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-booking
  /// Apply voucher to a booking
  Future<Map<String, dynamic>> applyVoucherToBooking(String redemptionId, String bookingId) {
    return post<Map<String, dynamic>>(
      '/api/ev/loyalty/vouchers/redemptions/$redemptionId/apply-to-booking',
      data: {'bookingId': bookingId},
    );
  }

  /// POST /api/ev/loyalty/vouchers/redemptions/{redemptionId}/apply-to-swap
  /// Apply voucher to a battery swap reservation
  Future<Map<String, dynamic>> applyVoucherToSwap(String redemptionId, String reservationId) {
    return post<Map<String, dynamic>>(
      '/api/ev/loyalty/vouchers/redemptions/$redemptionId/apply-to-swap',
      data: {'bookingId': reservationId},
    );
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
    List<Map<String, dynamic>>? checklistAnswers,
  }) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/tasks/$taskId/check-in',
      data: {
        'lat': lat,
        'lng': lng,
        if (deviceNote != null) 'deviceNote': deviceNote,
        if (checklistAnswers != null) 'checklistAnswers': checklistAnswers,
      },
    );
  }

  /// POST /api/collab/mobile/files/presign-upload
  Future<Map<String, dynamic>> presignUpload({String? contentType}) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/files/presign-upload',
      queryParameters: {
        if (contentType != null) 'contentType': contentType,
      },
    );
  }

  /// POST /api/collab/mobile/files/upload
  /// Proxy upload — backend receives file and forwards to MinIO.
  /// Use this instead of presigned URL when client cannot reach MinIO directly.
  Future<Map<String, dynamic>> proxyUpload({
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      ),
      'contentType': contentType,
    });
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/files/upload',
      data: formData,
    );
  }

  /// GET /api/collab/mobile/files/presign-view
  Future<Map<String, dynamic>> presignView({
    required String objectKey,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/mobile/files/presign-view',
      queryParameters: {
        'objectKey': objectKey,
      },
    );
  }

  /// GET /api/collab/mobile/files/view?objectKey=...
  /// Proxy view — backend streams file from MinIO to client.
  /// Returns raw bytes; use Image.memory(bytes) to display.
  Future<Uint8List> proxyViewBytes({required String objectKey}) {
    return getBytes(
      '/api/collab/mobile/files/view',
      queryParameters: {'objectKey': objectKey},
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

  // ============================================
  // Battery Swap Verification Endpoints
  // ============================================

  /// POST /api/mobile/collab/battery-swap/verification/tasks/{id}/checkin
  Future<Map<String, dynamic>> batterySwapCheckIn({
    required String taskId,
    required double lat,
    required double lng,
    int? actualTotalBatteries,
    int? actualAvailableBatteries,
    double? observedAvgChargePowerKw,
    String? deviceNote,
    List<Map<String, dynamic>>? checklistAnswers,
  }) {
    return post<Map<String, dynamic>>(
      '/api/mobile/collab/battery-swap/verification/tasks/$taskId/checkin',
      data: {
        'lat': lat,
        'lng': lng,
        if (actualTotalBatteries != null) 'actualTotalBatteries': actualTotalBatteries,
        if (actualAvailableBatteries != null) 'actualAvailableBatteries': actualAvailableBatteries,
        if (observedAvgChargePowerKw != null) 'observedAvgChargePowerKw': observedAvgChargePowerKw,
        if (deviceNote != null) 'deviceNote': deviceNote,
        if (checklistAnswers != null) 'checklistAnswers': checklistAnswers,
      },
    );
  }

  /// POST /api/mobile/collab/battery-swap/verification/tasks/{id}/evidence
  Future<Map<String, dynamic>> batterySwapSubmitEvidence({
    required String taskId,
    required String photoObjectKey,
    String? note,
  }) {
    return post<Map<String, dynamic>>(
      '/api/mobile/collab/battery-swap/verification/tasks/$taskId/evidence',
      data: {
        'photoObjectKey': photoObjectKey,
        if (note != null) 'note': note,
      },
    );
  }

  // ============================================
  // Notification Endpoints
  // ============================================

  /// GET /api/collab/notifications
  /// Get paginated list of notifications with optional filters
  Future<Map<String, dynamic>> getNotifications({
    String? category,
    bool? isRead,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/notifications',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (isRead != null) 'isRead': isRead.toString(),
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/collab/notifications/unread-count
  /// Get count of unread notifications
  Future<int> getUnreadNotificationCount() async {
    final response = await dio.get('/api/collab/notifications/unread-count');
    return response.data as int;
  }

  /// PATCH /api/collab/notifications/{id}/read
  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) {
    return patch<void>('/api/collab/notifications/$notificationId/read');
  }

  /// PATCH /api/collab/notifications/read-all
  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() {
    return patch<void>('/api/collab/notifications/read-all');
  }

  /// POST /api/collab/notifications/push-token
  /// Register FCM push token
  Future<void> registerPushToken({
    required String token,
    required String deviceType,
  }) {
    return post<void>(
      '/api/collab/notifications/push-token',
      data: {
        'token': token,
        'deviceType': deviceType,
      },
    );
  }

  /// GET /api/collab/notifications/preferences
  /// Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences() {
    return get<Map<String, dynamic>>('/api/collab/notifications/preferences');
  }

  /// PUT /api/collab/notifications/preferences
  /// Save notification preferences
  Future<void> saveNotificationPreferences(Map<String, dynamic> preferences) {
    return put<void>(
      '/api/collab/notifications/preferences',
      data: preferences,
    );
  }
  /// GET /api/collab/web/tasks/kpi
  /// Get monthly KPI (reviewedCount, passCount, failCount)
  Future<Map<String, dynamic>> getKpi() {
    return get<Map<String, dynamic>>('/api/collab/web/tasks/kpi');
  }

  /// GET /api/collab/web/me/contracts
  /// Get my contracts with active flag
  Future<List<dynamic>> getContracts() {
    return get<List<dynamic>>('/api/collab/web/me/contracts');
  }

  // ============================================
  // Change Request Endpoints (added 2026-06)
  // ============================================

  /// POST /api/collab/mobile/change-requests
  /// Create a charging-station change request (CREATE_STATION or UPDATE_STATION).
  Future<Map<String, dynamic>> createChangeRequest(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/change-requests',
      data: data,
    );
  }

  /// GET /api/collab/mobile/change-requests/mine
  /// Get all charging-station change requests submitted by the current collaborator.
  Future<List<dynamic>> getMyChangeRequests() {
    return get<List<dynamic>>('/api/collab/mobile/change-requests/mine');
  }

  /// GET /api/collab/mobile/change-requests/{id}
  Future<Map<String, dynamic>> getChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/collab/mobile/change-requests/$id');
  }

  /// POST /api/collab/mobile/change-requests/{id}/submit
  /// Submit a DRAFT change request for admin review.
  Future<Map<String, dynamic>> submitChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/collab/mobile/change-requests/$id/submit');
  }

  /// PUT /api/collab/mobile/change-requests/{id}
  /// Update a DRAFT change request.
  Future<Map<String, dynamic>> updateChangeRequest(String id, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>(
      '/api/collab/mobile/change-requests/$id',
      data: data,
    );
  }

  // ----- Battery Swap Change Requests -----

  /// POST /api/collab/mobile/battery-swap-change-requests
  Future<Map<String, dynamic>> createBatterySwapChangeRequest(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>(
      '/api/collab/mobile/battery-swap-change-requests',
      data: data,
    );
  }

  /// GET /api/collab/mobile/battery-swap-change-requests/mine
  Future<List<dynamic>> getMyBatterySwapChangeRequests() {
    return get<List<dynamic>>('/api/collab/mobile/battery-swap-change-requests/mine');
  }

  /// GET /api/collab/mobile/battery-swap-change-requests/{id}
  Future<Map<String, dynamic>> getBatterySwapChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/collab/mobile/battery-swap-change-requests/$id');
  }

  /// POST /api/collab/mobile/battery-swap-change-requests/{id}/submit
  Future<Map<String, dynamic>> submitBatterySwapChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/collab/mobile/battery-swap-change-requests/$id/submit');
  }

  // ----- Station search & auto-fill (added 2026-06-14) -----

  /// GET /api/collab/mobile/stations/search/by-name?name={q}&page=&size=
  /// Returns a paginated list of PUBLISHED charging stations whose name matches.
  Future<Map<String, dynamic>> searchChargingStationsByName(
    String name, {
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/mobile/stations/search/by-name',
      queryParameters: {
        'name': name,
        'page': '$page',
        'size': '$size',
      },
    );
  }

  /// GET /api/collab/mobile/stations/{stationId}
  /// Returns the full published charging-station detail (name, address, lat, lng,
  /// operating hours, ports, battery-swap info if supported).
  Future<Map<String, dynamic>> getChargingStationDetail(String stationId) {
    return get<Map<String, dynamic>>('/api/collab/mobile/stations/$stationId');
  }

  /// GET /api/collab/mobile/battery-swap-stations/search/by-name?search={q}&page=&size=
  Future<Map<String, dynamic>> searchBatterySwapStationsByName(
    String search, {
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/mobile/battery-swap-stations/search/by-name',
      queryParameters: {
        'search': search,
        'page': '$page',
        'size': '$size',
      },
    );
  }

  /// GET /api/collab/mobile/battery-swap-stations/{stationId}
  Future<Map<String, dynamic>> getBatterySwapStationDetail(String stationId) {
    return get<Map<String, dynamic>>('/api/collab/mobile/battery-swap-stations/$stationId');
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

  // ============================================
  // Battery Swap Verification Tasks Endpoints
  // ============================================

  /// GET /api/collab/web/battery-swap/tasks
  Future<Map<String, dynamic>> getBatterySwapTasks({
    String? status,
    int page = 0,
    int size = 50,
  }) {
    return get<Map<String, dynamic>>(
      '/api/collab/web/battery-swap/tasks',
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/collab/web/battery-swap/tasks/{id}
  Future<Map<String, dynamic>> getBatterySwapTask(String id) {
    return get<Map<String, dynamic>>('/api/collab/web/battery-swap/tasks/$id');
  }

  /// GET /api/collab/web/battery-swap/kpi
  Future<Map<String, dynamic>> getBatterySwapKpi() {
    return get<Map<String, dynamic>>('/api/collab/web/battery-swap/kpi');
  }
}

/// Public API Client
/// Endpoints: /api/public/** (no auth required)
class PublicApiClient extends BaseApiClient {
  PublicApiClient(super.dio);

  /// GET /api/public/battery-swap/stations
  Future<List<dynamic>> getAllSwapStations() {
    return get<List<dynamic>>('/api/public/battery-swap/stations');
  }

  /// GET /api/public/battery-swap/stations/{stationId}
  Future<Map<String, dynamic>> getStationDetail(String stationId) {
    return get<Map<String, dynamic>>('/api/public/battery-swap/stations/$stationId');
  }

  /// GET /api/public/battery-swap/stations/{stationId}/piles
  Future<Map<String, dynamic>> getStationPiles(String stationId) {
    return get<Map<String, dynamic>>('/api/public/battery-swap/stations/$stationId/piles');
  }

  /// GET /api/public/battery-swap/stations/{stationId}/active-code
  Future<Map<String, dynamic>> getActiveSwapCode(String stationId) {
    return get<Map<String, dynamic>>('/api/public/battery-swap/stations/$stationId/active-code');
  }

  // ============================================
  // Collaborator Registration Endpoints
  // ============================================

  /// POST /api/public/registration-requests
  /// Submit a new collaborator registration request.
  /// Email is sent by the backend from the authenticated JWT token — no need to send it.
  Future<Map<String, dynamic>> submitRegistrationRequest({
    required String fullName,
    required String phone,
    required String dateOfBirth,
    required String address,
    required String idCardNumber,
    required String bankAccountNumber,
    required String bankName,
    String? contractAgreedAt,
  }) {
    return post<Map<String, dynamic>>(
      '/api/public/registration-requests',
      data: {
        'fullName': fullName,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'address': address,
        'idCardNumber': idCardNumber,
        'bankAccountNumber': bankAccountNumber,
        'bankName': bankName,
        'contractAgreedAt': contractAgreedAt ?? DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// GET /api/public/registration-requests/{id}
  /// Get registration request status by ID
  Future<Map<String, dynamic>> getRegistrationRequestStatus(String id) {
    return get<Map<String, dynamic>>('/api/public/registration-requests/$id');
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
    String? verificationType, // CHARGING or BATTERY_SWAP
    List<Map<String, dynamic>>? checklist,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/verification-tasks',
      data: {
        'stationId': stationId,
        if (changeRequestId != null) 'changeRequestId': changeRequestId,
        if (priority != null) 'priority': priority,
        if (slaDueAt != null) 'slaDueAt': slaDueAt,
        if (verificationType != null) 'verificationType': verificationType,
        if (checklist != null) 'checklist': checklist,
      },
    );
  }

  /// GET /api/admin/verification-tasks
  Future<Map<String, dynamic>> getVerificationTasks({
    String? status,
    String? verificationType,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/verification-tasks',
      queryParameters: {
        if (status != null) 'status': status,
        if (verificationType != null) 'verificationType': verificationType,
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

  /// DELETE /api/admin/verification-tasks/{id}
  Future<void> deleteVerificationTask(String id) {
    return delete<void>('/api/admin/verification-tasks/$id');
  }

  /// POST /api/admin/verification-tasks/{id}/review
  Future<Map<String, dynamic>> reviewVerificationTask({
    required String id,
    required String result, // PASS or FAIL
    String? adminNote,
    bool? swapStationVerified,
    bool? inventoryAccurate,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/verification-tasks/$id/review',
      data: {
        'result': result,
        if (adminNote != null) 'adminNote': adminNote,
        if (swapStationVerified != null) 'swapStationVerified': swapStationVerified,
        if (inventoryAccurate != null) 'inventoryAccurate': inventoryAccurate,
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

  /// GET /api/admin/stations/trust/summary
  Future<Map<String, dynamic>> getStationsTrustSummary() {
    return get<Map<String, dynamic>>('/api/admin/stations/trust/summary');
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

  /// POST /api/admin/collaborators/with-account
  /// Create a new user account and collaborator profile in one step
  Future<Map<String, dynamic>> createCollaboratorWithAccount({
    required String email,
    required String password,
    required String fullName,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/collaborators/with-account',
      data: {
        'email': email,
        'password': password,
        'fullName': fullName,
      },
    );
  }

  /// DELETE /api/admin/collaborators/{id}
  /// Delete a collaborator profile and associated user account
  Future<void> deleteCollaborator(String id) {
    return delete<void>('/api/admin/collaborators/$id');
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
    String? search,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/stations',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'search': search,
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

  // ============================================
  // Battery Swap Change Request Endpoints
  // ============================================

  /// GET /api/admin/battery-swap/change-requests
  Future<List<dynamic>> getBatterySwapChangeRequests({String? status}) {
    return get<List<dynamic>>(
      '/api/admin/battery-swap/change-requests',
      queryParameters: status != null ? {'status': status} : null,
    );
  }

  /// GET /api/admin/battery-swap/change-requests/{id}
  Future<Map<String, dynamic>> getBatterySwapChangeRequest(String id) {
    return get<Map<String, dynamic>>('/api/admin/battery-swap/change-requests/$id');
  }

  /// POST /api/admin/battery-swap/change-requests/{id}/approve
  Future<Map<String, dynamic>> approveBatterySwapChangeRequest(String id, {String? note}) {
    return post<Map<String, dynamic>>(
      '/api/admin/battery-swap/change-requests/$id/approve',
      data: note != null ? {'note': note} : null,
    );
  }

  /// POST /api/admin/battery-swap/change-requests/{id}/reject
  Future<Map<String, dynamic>> rejectBatterySwapChangeRequest(String id, {required String reason}) {
    return post<Map<String, dynamic>>(
      '/api/admin/battery-swap/change-requests/$id/reject',
      data: {'reason': reason},
    );
  }

  /// POST /api/admin/battery-swap/change-requests/{id}/publish
  Future<Map<String, dynamic>> publishBatterySwapChangeRequest(String id) {
    return post<Map<String, dynamic>>('/api/admin/battery-swap/change-requests/$id/publish');
  }

  // ============================================
  // Battery Swap Trust Endpoints
  // ============================================

  /// GET /api/admin/battery-swap/trust/{stationId}
  Future<Map<String, dynamic>> getBatterySwapTrust(String stationId) {
    return get<Map<String, dynamic>>('/api/admin/battery-swap/trust/$stationId');
  }

  /// GET /api/admin/battery-swap/trust/{stationId}/breakdown
  Future<Map<String, dynamic>> getBatterySwapTrustBreakdown(String stationId) {
    return get<Map<String, dynamic>>('/api/admin/battery-swap/trust/$stationId/breakdown');
  }

  /// GET /api/admin/battery-swap/trust/{stationId}/level
  Future<String> getBatterySwapTrustLevel(String stationId) {
    return get<String>('/api/admin/battery-swap/trust/$stationId/level');
  }

  /// POST /api/admin/battery-swap/trust/{stationId}/recalculate
  Future<Map<String, dynamic>> recalculateBatterySwapTrust(String stationId) {
    return post<Map<String, dynamic>>('/api/admin/battery-swap/trust/$stationId/recalculate');
  }

  /// GET /api/admin/battery-swap/trust/summary
  Future<Map<String, dynamic>> getBatterySwapTrustSummary() {
    return get<Map<String, dynamic>>('/api/admin/battery-swap/trust/summary');
  }

  // ============================================
  // Battery Swap Station Management Endpoints
  // ============================================

  /// GET /api/admin/battery-swap/stations
  Future<Map<String, dynamic>> getBatterySwapStations({int page = 0, int size = 20, String? search}) {
    return get<Map<String, dynamic>>(
      '/api/admin/battery-swap/stations',
      queryParameters: {
        'page': page,
        'size': size,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
  }

  /// GET /api/admin/battery-swap/stations/{stationId}
  Future<Map<String, dynamic>> getBatterySwapStation(String stationId) {
    return get<Map<String, dynamic>>('/api/admin/battery-swap/stations/$stationId');
  }

  /// POST /api/admin/battery-swap/stations
  /// Create a new battery swap station
  Future<Map<String, dynamic>> createBatterySwapStation(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/admin/battery-swap/stations', data: data);
  }

  /// PUT /api/admin/battery-swap/stations/{stationId}
  /// Update a battery swap station directly (admin edit)
  Future<Map<String, dynamic>> updateBatterySwapStation(String stationId, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>(
      '/api/admin/battery-swap/stations/$stationId',
      data: data,
    );
  }

  /// DELETE /api/admin/battery-swap/stations/{stationId}
  /// Permanently delete a battery swap station
  Future<void> deleteBatterySwapStation(String stationId) {
    return delete<void>('/api/admin/battery-swap/stations/$stationId');
  }

  /// POST /api/admin/battery-swap/change-requests
  Future<Map<String, dynamic>> createBatterySwapChangeRequest(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>(
      '/api/admin/battery-swap/change-requests',
      data: data,
    );
  }

  /// PUT /api/admin/battery-swap/change-requests/{id}
  /// Update a DRAFT battery swap change request
  Future<Map<String, dynamic>> updateBatterySwapChangeRequest(String crId, Map<String, dynamic> data) {
    return put<Map<String, dynamic>>(
      '/api/admin/battery-swap/change-requests/$crId',
      data: data,
    );
  }

  // ============================================
  // Dashboard Analytics Endpoints
  // ============================================

  /// GET /api/admin/dashboard/stats
  Future<Map<String, dynamic>> getDashboardStats() {
    return get<Map<String, dynamic>>('/api/admin/dashboard/stats');
  }

  /// GET /api/admin/dashboard/trends
  Future<Map<String, dynamic>> getDashboardTrends({int days = 30}) {
    return get<Map<String, dynamic>>(
      '/api/admin/dashboard/trends',
      queryParameters: {'days': days},
    );
  }

  /// GET /api/admin/dashboard/booking-stats
  Future<Map<String, dynamic>> getBookingStats() {
    return get<Map<String, dynamic>>('/api/admin/dashboard/booking-stats');
  }

  /// GET /api/admin/dashboard/issue-stats
  Future<Map<String, dynamic>> getIssueStats() {
    return get<Map<String, dynamic>>('/api/admin/dashboard/issue-stats');
  }

  /// GET /api/admin/dashboard/trust-overview
  Future<Map<String, dynamic>> getTrustOverview({
    int page = 0,
    int size = 20,
    String? sortBy,
    String? sortDir,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/dashboard/trust-overview',
      queryParameters: {
        'page': page,
        'size': size,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortDir != null) 'sortDir': sortDir,
      },
    );
  }
  // ============================================
  // Collaborator Performance Endpoints
  // ============================================

  /// GET /api/admin/collaborators/performance
  Future<Map<String, dynamic>> getCollaboratorsPerformance({
    int page = 0,
    int size = 20,
    String? sortBy,
    String? sortDir,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/collaborators/performance',
      queryParameters: {
        'page': page,
        'size': size,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortDir != null) 'sortDir': sortDir,
      },
    );
  }

  /// GET /api/admin/collaborators/{id}/performance
  Future<Map<String, dynamic>> getCollaboratorPerformanceDetail(String collaboratorId) {
    return get<Map<String, dynamic>>('/api/admin/collaborators/$collaboratorId/performance');
  }

  // ============================================
  // Collaborator Registration Request Management
  // ============================================

  /// GET /api/admin/registration-requests
  /// Get paginated list of registration requests with optional status filter
  Future<Map<String, dynamic>> getRegistrationRequests({
    int page = 0,
    int size = 20,
    String? status,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/registration-requests',
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// GET /api/admin/registration-requests/{id}
  /// Get a single registration request by ID
  Future<Map<String, dynamic>> getRegistrationRequest(String id) {
    return get<Map<String, dynamic>>('/api/admin/registration-requests/$id');
  }

  /// POST /api/admin/registration-requests/{id}/approve
  /// Approve a registration request
  Future<Map<String, dynamic>> approveRegistrationRequest(String id, {
    required String region,
    String? note,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/registration-requests/$id/approve',
      data: {
        'region': region,
        if (note != null) 'note': note,
      },
    );
  }

  /// POST /api/admin/registration-requests/{id}/reject
  /// Reject a registration request
  Future<Map<String, dynamic>> rejectRegistrationRequest(String id, {
    required String reason,
  }) {
    return post<Map<String, dynamic>>(
      '/api/admin/registration-requests/$id/reject',
      data: {
        'reason': reason,
      },
    );
  }

  /// GET /api/admin/registration-requests/pending-count
  /// Get count of pending registration requests
  Future<int> getRegistrationRequestsPendingCount() async {
    final response = await dio.get('/api/admin/registration-requests/pending-count');
    return response.data as int;
  }

  // ============================================
  // Loyalty Point System Admin Endpoints
  // ============================================

  /// GET /api/admin/loyalty/users/{userId}
  /// Get a user's loyalty profile
  Future<Map<String, dynamic>> getUserLoyaltyProfile(String userId) {
    return get<Map<String, dynamic>>('/api/admin/loyalty/users/$userId');
  }

  /// GET /api/admin/loyalty/users/{userId}/history
  /// Get a user's point transaction history
  Future<Map<String, dynamic>> getUserPointHistory(
    String userId, {
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/loyalty/users/$userId/history',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// POST /api/admin/loyalty/users/{userId}/adjust
  /// Adjust a user's points manually
  Future<void> adjustUserPoints(
    String userId, {
    required int delta,
    required String reason,
  }) {
    return post<void>(
      '/api/admin/loyalty/users/$userId/adjust',
      data: {
        'delta': delta,
        'reason': reason,
      },
    );
  }

  /// PUT /api/admin/loyalty/ratings/{id}/hide
  /// Hide a rating
  Future<void> hideRating(String ratingId) {
    return put<void>('/api/admin/loyalty/ratings/$ratingId/hide');
  }

  /// GET /api/admin/loyalty/badges
  /// Get all badges with progress info
  Future<List<dynamic>> getAllBadges() {
    return get<List<dynamic>>('/api/admin/loyalty/badges');
  }

  // ============================================
  // Loyalty Dashboard & User/Rating Endpoints
  // ============================================

  /// GET /api/admin/loyalty/dashboard
  /// Get loyalty dashboard stats (total points, active users, total ratings)
  Future<Map<String, dynamic>> getLoyaltyDashboard() {
    return get<Map<String, dynamic>>('/api/admin/loyalty/dashboard');
  }

  /// GET /api/admin/loyalty/users
  /// Get paginated list of all users with loyalty profiles
  Future<Map<String, dynamic>> getLoyaltyUsers({
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/loyalty/users',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
  }

  /// GET /api/admin/loyalty/ratings
  /// Get paginated list of all ratings with optional filters
  Future<Map<String, dynamic>> getLoyaltyRatings({
    String? stationId,
    String? status,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/loyalty/ratings',
      queryParameters: {
        'page': page,
        'size': size,
        if (stationId != null && stationId.isNotEmpty) 'stationId': stationId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  /// GET /api/admin/loyalty/vouchers/{id}/stats
  /// Get voucher redemption stats
  Future<Map<String, dynamic>> getVoucherStats(String voucherId) {
    return get<Map<String, dynamic>>('/api/admin/loyalty/vouchers/$voucherId/stats');
  }

  // ============================================
  // Voucher Management Admin Endpoints
  // ============================================

  /// GET /api/admin/loyalty/vouchers
  /// Get all voucher definitions
  Future<List<dynamic>> getVouchers() {
    return get<List<dynamic>>('/api/admin/loyalty/vouchers');
  }

  /// POST /api/admin/loyalty/vouchers
  /// Create a new voucher definition
  Future<Map<String, dynamic>> createVoucher(Map<String, dynamic> data) {
    return post<Map<String, dynamic>>('/api/admin/loyalty/vouchers', data: data);
  }

  /// PATCH /api/admin/loyalty/vouchers/{id}/status
  /// Update voucher status (ACTIVE/INACTIVE/ARCHIVED)
  Future<void> updateVoucherStatus(String id, String status) {
    return patch<void>(
      '/api/admin/loyalty/vouchers/$id/status',
      data: {'status': status},
    );
  }

  /// GET /api/admin/loyalty/vouchers/{id}
  /// Get voucher definition by ID
  Future<Map<String, dynamic>> getVoucher(String id) {
    return get<Map<String, dynamic>>('/api/admin/loyalty/vouchers/$id');
  }

  /// DELETE /api/admin/loyalty/vouchers/{id}
  /// Delete a voucher definition
  Future<void> deleteVoucher(String id) {
    return delete<void>('/api/admin/loyalty/vouchers/$id');
  }

  /// GET /api/admin/loyalty/redemptions
  /// Get paginated list of all voucher redemptions
  Future<Map<String, dynamic>> getVoucherRedemptions({
    String? status,
    int page = 0,
    int size = 20,
  }) {
    return get<Map<String, dynamic>>(
      '/api/admin/loyalty/redemptions',
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }
}

