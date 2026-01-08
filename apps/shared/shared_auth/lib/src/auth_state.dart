import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_response.dart';
import 'token_storage.dart';
import 'auth_service.dart';

/// Auth state model
class AuthState {
  final String? token;
  final String? userId;
  final String? email;
  final String? role;

  const AuthState({
    this.token,
    this.userId,
    this.email,
    this.role,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? userId,
    String? email,
    String? role,
    bool? clear,
  }) {
    if (clear == true) {
      return const AuthState();
    }
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

/// Auth state notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  final TokenStorage _tokenStorage;
  final AuthService? _authService;

  AuthStateNotifier(this._tokenStorage, [this._authService]) : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final token = await _tokenStorage.getToken();
    final userId = await _tokenStorage.getUserId();
    final email = await _tokenStorage.getEmail();
    final role = await _tokenStorage.getRole();

    if (token != null) {
      state = AuthState(
        token: token,
        userId: userId,
        email: email,
        role: role,
      );
    }
  }

  /// Login via API
  Future<void> login(String email, String password) async {
    if (_authService == null) {
      throw Exception('AuthService not provided');
    }
    final response = await _authService!.login(email, password);
    await _saveAuthResponse(response);
  }

  /// Register via API
  Future<void> register(String email, String password, String role) async {
    if (_authService == null) {
      throw Exception('AuthService not provided');
    }
    final response = await _authService!.register(email, password, role);
    await _saveAuthResponse(response);
  }

  /// Save auth response to storage and state
  Future<void> _saveAuthResponse(AuthResponse response) async {
    await _tokenStorage.saveToken(response.token);
    await _tokenStorage.saveUserId(response.userId);
    await _tokenStorage.saveEmail(response.email);
    await _tokenStorage.saveRole(response.role);

    state = AuthState(
      token: response.token,
      userId: response.userId,
      email: response.email,
      role: response.role,
    );
  }

  /// Direct login (for testing or manual token)
  Future<void> loginWithResponse(AuthResponse response) async {
    await _saveAuthResponse(response);
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = const AuthState();
  }
}

/// Auth state provider
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Auth service provider (must be provided by app via ProviderScope overrides)
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService must be provided via ProviderScope.overrides');
});

final authStateNotifierProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(tokenStorage, authService);
});

final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authStateNotifierProvider);
});

/// Typedef for AuthStateProviderRef (used in interceptors)
typedef AuthStateProviderRef = Ref;

