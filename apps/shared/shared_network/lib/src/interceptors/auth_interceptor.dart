import 'package:dio/dio.dart';
import 'package:shared_auth/shared_auth.dart';

/// Interceptor to attach Authorization header with Bearer token
/// 
/// Reads token from AuthStateProvider (Riverpod) and attaches to all requests
class AuthInterceptor extends Interceptor {
  final AuthStateProviderRef ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authState = ref.read(authStateProvider);
    
    if (authState.isAuthenticated && authState.token != null) {
      options.headers['Authorization'] = 'Bearer ${authState.token}';
    }

    handler.next(options);
  }
}

