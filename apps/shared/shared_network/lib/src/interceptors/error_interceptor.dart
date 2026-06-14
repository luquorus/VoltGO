import 'package:dio/dio.dart';
import '../api_error.dart';

/// Interceptor to map Dio errors to ApiError model
///
/// Maps HTTP error responses (400, 401, 403, 404, etc.) to ApiError
/// according to OpenAPI schema
class ErrorInterceptor extends Interceptor {
  /// Optional callback invoked when the server responds with 401. The
  /// application can use this to wipe local credentials and bounce the
  /// user back to the login screen instead of showing a generic error.
  final void Function()? onUnauthorized;

  const ErrorInterceptor({this.onUnauthorized});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      final statusCode = err.response!.statusCode;
      final data = err.response!.data;

      // 401: surface to the host app so it can clear the session. The
      // thrown ApiError is still propagated so individual screens can
      // show a "session expired" message if they want to.
      if (statusCode == 401) {
        try {
          onUnauthorized?.call();
        } catch (_) {
          // Never let the auth-clearing callback break request rejection.
        }
      }

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

