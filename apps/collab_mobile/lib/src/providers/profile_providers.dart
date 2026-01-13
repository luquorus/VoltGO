import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../repositories/profile_repository.dart';

/// Base URL Provider
final baseUrlProvider = Provider<String>((ref) {
  return dotenv.get('BASE_URL', fallback: 'http://localhost:8080');
});

/// Dio Client Provider
final dioClientProvider = Provider.family<Dio, String>((ref, baseUrl) {
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
});

/// Profile Repository Provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  final dio = ref.read(dioClientProvider(baseUrl));
  final authState = ref.watch(authStateProvider);
  
  return ProfileRepository(
    dio,
    getToken: () => authState.token,
  );
});

/// Profile State
class ProfileState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final ApiError? error;

  ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    bool? isLoading,
    ApiError? error,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return ProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Profile Notifier
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;

  ProfileNotifier(this._repository) : super(ProfileState());

  /// Load profile
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final profile = await _repository.getMyProfile();
      state = state.copyWith(
        profile: profile,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Update profile
  Future<bool> updateProfile({required String name, String? phone}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final updated = await _repository.updateProfile(name: name, phone: phone);
      state = state.copyWith(
        profile: updated,
        isLoading: false,
      );
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
      return false;
    }
  }
}

/// Profile Provider
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repository);
});

