import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../repositories/issue_repository.dart';

/// Issue Repository Provider
final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return IssueRepository(factory.ev);
});

/// Report Issue State
class ReportIssueState {
  final bool isSubmitting;
  final ApiError? error;

  ReportIssueState({
    this.isSubmitting = false,
    this.error,
  });

  ReportIssueState copyWith({
    bool? isSubmitting,
    ApiError? error,
    bool clearError = false,
  }) {
    return ReportIssueState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Report Issue Notifier
class ReportIssueNotifier extends StateNotifier<ReportIssueState> {
  final IssueRepository _repository;

  ReportIssueNotifier(this._repository) : super(ReportIssueState());

  /// Report an issue
  Future<Map<String, dynamic>?> reportIssue({
    required String stationId,
    required String category,
    required String description,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final response = await _repository.reportIssue(
        stationId: stationId,
        category: category,
        description: description,
      );
      state = state.copyWith(isSubmitting: false);
      return response;
    } on ApiError catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
      return null;
    }
  }
}

/// Report Issue Provider
final reportIssueProvider =
    StateNotifierProvider<ReportIssueNotifier, ReportIssueState>((ref) {
  final repository = ref.watch(issueRepositoryProvider);
  return ReportIssueNotifier(repository);
});

/// My Issues State
class MyIssuesState {
  final List<Map<String, dynamic>> issues;
  final bool isLoading;
  final ApiError? error;

  MyIssuesState({
    this.issues = const [],
    this.isLoading = false,
    this.error,
  });

  MyIssuesState copyWith({
    List<Map<String, dynamic>>? issues,
    bool? isLoading,
    ApiError? error,
    bool clearError = false,
    bool clearIssues = false,
  }) {
    return MyIssuesState(
      issues: clearIssues ? [] : (issues ?? this.issues),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// My Issues Notifier
class MyIssuesNotifier extends StateNotifier<MyIssuesState> {
  final IssueRepository _repository;

  MyIssuesNotifier(this._repository) : super(MyIssuesState());

  /// Load my issues
  Future<void> loadIssues() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final issues = await _repository.getMyIssues();
      final issuesList = issues
          .map((e) => e as Map<String, dynamic>)
          .toList();
      state = state.copyWith(
        issues: issuesList,
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

  /// Refresh issues
  Future<void> refresh() async {
    await loadIssues();
  }
}

/// My Issues Provider
final myIssuesProvider =
    StateNotifierProvider<MyIssuesNotifier, MyIssuesState>((ref) {
  final repository = ref.watch(issueRepositoryProvider);
  return MyIssuesNotifier(repository);
});

