import 'package:dio/dio.dart';
import '../api_error.dart';

/// Interceptor to map Dio errors to ApiError model
/// 
/// Maps HTTP error responses (400, 401, 403, 404, etc.) to ApiError
/// according to OpenAPI schema
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      final statusCode = err.response!.statusCode;
      final data = err.response!.data;

      // Try to parse as ApiError if response is JSON
      if (data is Map<String, dynamic>) {
        try {
          final apiError = ApiError.fromJson(data);
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: err.type,
              error: apiError,
            ),
          );
          return;
        } catch (e) {
          // If parsing fails, create a generic ApiError
          final apiError = ApiError(
            traceId: err.response?.headers.value('X-Request-Id') ?? '',
            code: 'HTTP-$statusCode',
            message: data['message'] as String? ?? err.message ?? 'Unknown error',
            details: data,
            timestamp: DateTime.now(),
          );
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: err.response,
              type: err.type,
              error: apiError,
            ),
          );
          return;
        }
      }
    }

    // For network errors or other DioException types
    handler.next(err);
  }
}

