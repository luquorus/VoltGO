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

  // TODO: Add typed API clients when OpenAPI codegen is set up
  // 
  // Example structure:
  // 
  // /// EV User Mobile API client
  // /// Endpoints: /api/ev/**
  // EvUserMobileApi get evUserMobile => EvUserMobileApi(dio);
  // 
  // /// Collaborator Mobile API client
  // /// Endpoints: /api/collab/mobile/**
  // CollaboratorMobileApi get collaboratorMobile => CollaboratorMobileApi(dio);
  // 
  // /// Collaborator Web API client
  // /// Endpoints: /api/collab/web/**
  // CollaboratorWebApi get collaboratorWeb => CollaboratorWebApi(dio);
  // 
  // /// Admin Web API client
  // /// Endpoints: /api/admin/**
  // AdminWebApi get adminWeb => AdminWebApi(dio);
}

/// Provider for ApiClientFactory
final apiClientFactoryProvider = StateProvider<ApiClientFactory?>((ref) => null);

