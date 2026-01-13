import 'package:dio/dio.dart';
import 'package:shared_network/shared_network.dart';

/// Profile Repository
class ProfileRepository {
  final Dio _dio;
  final String? Function()? _getToken;

  ProfileRepository(
    this._dio, {
    String? Function()? getToken,
  }) : _getToken = getToken;

  /// Get my profile
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final token = _getToken?.call();
      final response = await _dio.get(
        '/api/profile/me',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiError(
        traceId: '',
        code: e.response?.statusCode.toString() ?? 'UNKNOWN_ERROR',
        message: e.response?.data?['message'] ?? e.message ?? 'Failed to get profile',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Update my profile
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
  }) async {
    try {
      final token = _getToken?.call();
      final response = await _dio.put(
        '/api/profile/me',
        data: {
          'name': name,
          if (phone != null) 'phone': phone,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiError(
        traceId: '',
        code: e.response?.statusCode.toString() ?? 'UNKNOWN_ERROR',
        message: e.response?.data?['message'] ?? e.message ?? 'Failed to update profile',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = _getToken?.call();
      final response = await _dio.post(
        '/api/profile/me/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiError(
        traceId: '',
        code: e.response?.statusCode.toString() ?? 'UNKNOWN_ERROR',
        message: e.response?.data?['message'] ?? e.message ?? 'Failed to change password',
        timestamp: DateTime.now(),
      );
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

