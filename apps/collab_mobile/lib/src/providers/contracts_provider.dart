import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../models/contract.dart';
import '../repositories/task_repository.dart';
import 'task_providers.dart';

/// Contracts State
class ContractsState {
  final List<Contract> contracts;
  final bool isLoading;
  final ApiError? error;

  ContractsState({
    this.contracts = const [],
    this.isLoading = false,
    this.error,
  });

  Contract? get activeContract {
    try {
      return contracts.firstWhere((c) => c.isActive);
    } catch (_) {
      return null;
    }
  }
}

/// Contracts Notifier
class ContractsNotifier extends StateNotifier<ContractsState> {
  final CollaboratorMobileApiClient _apiClient;

  ContractsNotifier(this._apiClient) : super(ContractsState());

  Future<void> loadContracts() async {
    state = ContractsState(isLoading: true);
    try {
      final response = await _apiClient.getContracts();
      final contracts = (response as List)
          .map((json) => Contract.fromJson(json as Map<String, dynamic>))
          .toList();
      state = ContractsState(contracts: contracts);
    } on ApiError catch (e) {
      state = ContractsState(error: e);
    } catch (e) {
      state = ContractsState(
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }
}

/// Contracts Provider
final contractsProvider =
    StateNotifierProvider<ContractsNotifier, ContractsState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return ContractsNotifier(repository.apiClient);
});
