import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:dio/dio.dart';

export 'package:shared_network/shared_network.dart' show ApiError;

/// Station Repository using OpenAPI client
class StationRepository {
  final EvUserMobileApiClient _apiClient;
  final Dio? _dio;
  final String? _baseUrl;
  final String? Function()? _getToken;

  StationRepository(
    this._apiClient, {
    Dio? dio,
    String? baseUrl,
    String? Function()? getToken,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _getToken = getToken;

  /// Search stations within radius
  /// Returns PaginationResponse<StationListItem>
  Future<Map<String, dynamic>> searchStations({
    required double lat,
    required double lng,
    required double radiusKm,
    double? minPowerKw,
    bool? hasAC,
    int page = 0,
    int size = 20,
  }) async {
    try {
      return await _apiClient.getStations(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        minPowerKw: minPowerKw,
        hasAC: hasAC,
        page: page,
        size: size,
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get station detail by stationId
  /// Returns StationDetail
  Future<Map<String, dynamic>> getStationDetail(String stationId) async {
    try {
      return await _apiClient.getStation(stationId);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Search stations by name
  /// Returns PaginationResponse<StationListItem>
  Future<Map<String, dynamic>> searchStationsByName({
    required String name,
    int page = 0,
    int size = 20,
  }) async {
    try {
      return await _apiClient.searchStationsByName(
        name: name,
        page: page,
        size: size,
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get charger units for a station
  /// Returns List<ChargerUnit>
  Future<List<Map<String, dynamic>>> getChargerUnits(String stationId) async {
    try {
      final response = await _apiClient.getChargerUnits(stationId);
      return (response as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get availability for a station
  /// Returns AvailabilityResponse
  Future<Map<String, dynamic>> getAvailability({
    required String stationId,
    required DateTime date,
    String timezone = 'Asia/Bangkok',
    int slotMinutes = 30,
    String? powerType,
    double? minPowerKw,
  }) async {
    try {
      return await _apiClient.getAvailability(
        stationId: stationId,
        date: date.toIso8601String().split('T')[0], // YYYY-MM-DD
        tz: timezone,
        slotMinutes: slotMinutes,
        powerType: powerType,
        minPowerKw: minPowerKw,
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get station recommendations based on battery and location
  /// Returns RecommendationResponse
  Future<Map<String, dynamic>> getRecommendations({
    required double lat,
    required double lng,
    required double radiusKm,
    required int batteryPercent,
    required double batteryCapacityKwh,
    int? targetPercent,
    double? consumptionKwhPerKm,
    double? averageSpeedKmph,
    double? vehicleMaxChargeKw,
    int? limit,
  }) async {
    try {
      // Use HTTP directly since API client might not have this method yet
      if (_dio == null || _baseUrl == null) {
        throw ApiError(
          traceId: '',
          code: 'CONFIGURATION_ERROR',
          message: 'Dio client and baseUrl required for recommendations API',
          timestamp: DateTime.now(),
        );
      }

      // Get auth token
      final token = _getToken?.call();
      
      if (token == null) {
        throw ApiError(
          traceId: '',
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
          timestamp: DateTime.now(),
        );
      }

      // Build request body
      final requestBody = <String, dynamic>{
        'currentLocation': {
          'lat': lat,
          'lng': lng,
        },
        'radiusKm': radiusKm,
        'batteryPercent': batteryPercent,
        'batteryCapacityKwh': batteryCapacityKwh,
      };
      
      if (targetPercent != null) requestBody['targetPercent'] = targetPercent;
      if (consumptionKwhPerKm != null) requestBody['consumptionKwhPerKm'] = consumptionKwhPerKm;
      if (averageSpeedKmph != null) requestBody['averageSpeedKmph'] = averageSpeedKmph;
      if (vehicleMaxChargeKw != null) requestBody['vehicleMaxChargeKw'] = vehicleMaxChargeKw;
      if (limit != null) requestBody['limit'] = limit;

      // Make POST request
      final response = await _dio!.post(
        '$_baseUrl/api/ev/stations/recommendations',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        final errorData = e.response!.data;
        
        throw ApiError(
          traceId: errorData?['traceId'] as String? ?? '',
          code: errorData?['code'] as String? ?? 'HTTP_ERROR',
          message: errorData?['message'] as String? ?? e.message ?? 'Request failed',
          timestamp: DateTime.now(),
        );
      }
      throw ApiError(
        traceId: '',
        code: 'NETWORK_ERROR',
        message: e.message ?? 'Network request failed',
        timestamp: DateTime.now(),
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }
}

