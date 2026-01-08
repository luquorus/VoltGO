import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

// Conditional import for web adapter
import 'dio_web_adapter_stub.dart'
    if (dart.library.html) 'dio_web_adapter_web.dart' as web_adapter;

/// Dio client factory
/// 
/// Creates configured Dio instance with:
/// - Base URL from environment
/// - Auth interceptor (Bearer token)
/// - Error interceptor (ApiError mapping)
final dioClientProvider = Provider.family<Dio, String>((ref, baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add web adapter for Flutter web (handles CORS)
  if (kIsWeb) {
    web_adapter.setupWebAdapter(dio);
  }

  // Add interceptors
  dio.interceptors.add(ErrorInterceptor());
  // AuthInterceptor will be added by ApiClientFactory after auth state is available

  return dio;
});

