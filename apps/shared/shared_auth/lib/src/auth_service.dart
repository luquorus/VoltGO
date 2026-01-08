import 'package:dio/dio.dart';
import 'auth_response.dart';
import 'package:shared_network/shared_network.dart';

/// Auth service for login/register API calls
class AuthService {
  final Dio dio;

  AuthService(this.dio);

  /// Login endpoint: POST /auth/login
  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      // Handle network errors
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiError(
          traceId: '',
          code: 'NETWORK_ERROR',
          message: 'Cannot connect to server. Please check if backend is running at ${dio.options.baseUrl}',
          timestamp: DateTime.now(),
        );
      }
      
      // Handle API errors
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        try {
          throw ApiError.fromJson(e.response!.data as Map<String, dynamic>);
        } catch (_) {
          // If parsing fails, create generic error
          throw ApiError(
            traceId: '',
            code: 'HTTP_${e.response!.statusCode}',
            message: e.response!.data?.toString() ?? e.message ?? 'Unknown error',
            timestamp: DateTime.now(),
          );
        }
      }
      
      // Other DioException types
      throw ApiError(
        traceId: '',
        code: 'DIO_ERROR',
        message: e.message ?? 'Network request failed',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Register endpoint: POST /auth/register
  Future<AuthResponse> register(
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'role': role,
        },
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      // Handle network errors
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiError(
          traceId: '',
          code: 'NETWORK_ERROR',
          message: 'Cannot connect to server. Please check if backend is running at ${dio.options.baseUrl}',
          timestamp: DateTime.now(),
        );
      }
      
      // Handle API errors
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        try {
          throw ApiError.fromJson(e.response!.data as Map<String, dynamic>);
        } catch (_) {
          throw ApiError(
            traceId: '',
            code: 'HTTP_${e.response!.statusCode}',
            message: e.response!.data?.toString() ?? e.message ?? 'Unknown error',
            timestamp: DateTime.now(),
          );
        }
      }
      
      throw ApiError(
        traceId: '',
        code: 'DIO_ERROR',
        message: e.message ?? 'Network request failed',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }
}

