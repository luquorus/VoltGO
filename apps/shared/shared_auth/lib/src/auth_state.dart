import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_response.dart';
import 'token_storage.dart';
import 'auth_service.dart';
import 'package:shared_api/shared_api.dart';

/// Auth state model
class AuthState {
  final String? token;
  final String? userId;
  final String? email;
  final String? role;
  final String? status;  // ACTIVE, PENDING_COLLABORATOR, BANNED
  final bool registrationSubmitted;

  const AuthState({
    this.token,
    this.userId,
    this.email,
    this.role,
    this.status,
    this.registrationSubmitted = false,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isCollaborator => role == 'COLLABORATOR';
  bool get isPendingCollaborator => status == 'PENDING_COLLABORATOR';
  bool get isActive => status == 'ACTIVE';

  AuthState copyWith({
    String? token,
    String? userId,
    String? email,
    String? role,
    String? status,
    bool? registrationSubmitted,
    bool clear = false,
  }) {
    if (clear == true) {
      return const AuthState();
    }
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      registrationSubmitted: registrationSubmitted ?? this.registrationSubmitted,
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
    final status = await _tokenStorage.getStatus();
    final registrationSubmitted = await _tokenStorage.getRegistrationSubmitted();

    if (token != null) {
      state = AuthState(
        token: token,
        userId: userId,
        email: email,
        role: role,
        status: status,
        registrationSubmitted: registrationSubmitted,
      );
    }
  }

  /// Login via API (using AuthService or ApiClientFactory)
  Future<void> login(String email, String password) async {
    if (_authService != null) {
      final response = await _authService!.login(email, password);
      await _saveAuthResponse(response, registrationSubmitted: true);
    } else {
      throw Exception('AuthService or ApiClientFactory must be provided');
    }
  }

  /// Register via API (using AuthService or ApiClientFactory)
  /// registrationSubmitted=false because user just registered but hasn't submitted the form yet
  Future<void> register(String email, String password, String role) async {
    if (_authService != null) {
      final response = await _authService!.register(email, password, role);
      await _saveAuthResponse(response, registrationSubmitted: false);
    } else {
      throw Exception('AuthService or ApiClientFactory must be provided');
    }
  }

  /// Login via ApiClientFactory (new method)
  Future<void> loginWithApiClient(AuthApiClient authClient, String email, String password) async {
    final responseData = await authClient.login(email: email, password: password);
    final response = AuthResponse.fromJson(responseData);
    await _saveAuthResponse(response, registrationSubmitted: true);
  }

  /// Register via ApiClientFactory (new method)
  Future<void> registerWithApiClient(AuthApiClient authClient, String email, String password, String role) async {
    final responseData = await authClient.register(email: email, password: password, role: role);
    final response = AuthResponse.fromJson(responseData);
    await _saveAuthResponse(response, registrationSubmitted: false);
  }

  /// Save auth response to storage and state
  Future<void> _saveAuthResponse(AuthResponse response, {bool registrationSubmitted = false}) async {
    await _tokenStorage.saveToken(response.token);
    await _tokenStorage.saveUserId(response.userId);
    await _tokenStorage.saveEmail(response.email);
    await _tokenStorage.saveRole(response.role);
    await _tokenStorage.saveStatus(response.status);
    await _tokenStorage.saveRegistrationSubmitted(registrationSubmitted);

    state = AuthState(
      token: response.token,
      userId: response.userId,
      email: response.email,
      role: response.role,
      status: response.status,
      registrationSubmitted: registrationSubmitted,
    );
  }

  /// Direct login (for testing or manual token)
  Future<void> loginWithResponse(AuthResponse response) async {
    await _saveAuthResponse(response, registrationSubmitted: true);
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = const AuthState();
  }

  /// Mark that the registration form has been submitted
  Future<void> markRegistrationSubmitted() async {
    await _tokenStorage.saveRegistrationSubmitted(true);
    state = state.copyWith(registrationSubmitted: true);
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

