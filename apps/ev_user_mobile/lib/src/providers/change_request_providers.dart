import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import '../repositories/change_request_repository.dart';
import '../repositories/battery_swap_change_request_repository.dart';
import 'battery_swap_change_request_providers.dart';

/// Provider for ChangeRequestRepository
final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return ChangeRequestRepository(factory.ev);
});

/// Unified change request list item — wraps both charging and battery swap CRs.
class ChangeRequestListItem {
  final String id;
  final String kind; // 'CHARGING' or 'BATTERY_SWAP'
  final String type; // CREATE / UPDATE / etc.
  final String status;
  final DateTime? createdAt;
  final String stationName;

  ChangeRequestListItem({
    required this.id,
    required this.kind,
    required this.type,
    required this.status,
    this.createdAt,
    required this.stationName,
  });

  factory ChangeRequestListItem.fromChargingCR(Map<String, dynamic> cr) {
    final stationData = cr['stationData'] as Map<String, dynamic>?;
    return ChangeRequestListItem(
      id: cr['id'] as String? ?? '',
      kind: 'CHARGING',
      type: cr['type'] as String? ?? 'UNKNOWN',
      status: cr['status'] as String? ?? 'UNKNOWN',
      createdAt: _parseDateTime(cr['createdAt'] as String?),
      stationName: stationData?['name'] as String? ?? 'Unnamed station',
    );
  }

  factory ChangeRequestListItem.fromBatterySwapCR(Map<String, dynamic> cr) {
    return ChangeRequestListItem(
      id: cr['id'] as String? ?? '',
      kind: 'BATTERY_SWAP',
      type: cr['type'] as String? ?? 'UNKNOWN',
      status: cr['status'] as String? ?? 'UNKNOWN',
      createdAt: _parseDateTime(cr['createdAt'] as String?),
      stationName: cr['stationName'] as String? ?? 'Unnamed station',
    );
  }
}

DateTime? _parseDateTime(String? dateStr) {
  if (dateStr == null) return null;
  try {
    return DateTime.parse(dateStr).toLocal();
  } catch (e) {
    return null;
  }
}

/// Change request list state
class ChangeRequestListState {
  final List<ChangeRequestListItem> changeRequests;
  final bool isLoading;
  final String? error;

  ChangeRequestListState({
    this.changeRequests = const [],
    this.isLoading = false,
    this.error,
  });

  ChangeRequestListState copyWith({
    List<ChangeRequestListItem>? changeRequests,
    bool? isLoading,
    String? error,
  }) {
    return ChangeRequestListState(
      changeRequests: changeRequests ?? this.changeRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Change request list notifier — fetches both charging and battery swap CRs.
class ChangeRequestListNotifier extends StateNotifier<ChangeRequestListState> {
  final ChangeRequestRepository _repository;
  final BatterySwapChangeRequestRepository _bsRepository;

  ChangeRequestListNotifier(this._repository, this._bsRepository)
      : super(ChangeRequestListState()) {
    loadChangeRequests();
  }

  Future<void> loadChangeRequests() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch both in parallel
      final results = await Future.wait([
        _repository.getChangeRequests().then(
              (list) => list.map((e) => ChangeRequestListItem.fromChargingCR(e)).toList(),
            ),
        _bsRepository.getChangeRequests().then(
              (list) => list.map((e) => ChangeRequestListItem.fromBatterySwapCR(e)).toList(),
            ),
      ]);

      final allItems = [...results[0], ...results[1]];
      // Sort by createdAt descending (newest first)
      allItems.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(1970);
        final bTime = b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      state = state.copyWith(
        changeRequests: allItems,
        isLoading: false,
        error: null,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadChangeRequests();
}

/// Provider for change request list
final changeRequestListProvider =
    StateNotifierProvider.autoDispose<ChangeRequestListNotifier, ChangeRequestListState>(
        (ref) {
  final repository = ref.watch(changeRequestRepositoryProvider);
  final bsRepository = ref.watch(batterySwapChangeRequestRepositoryProvider);

  ref.listen(authStateProvider, (previous, next) {
    if (previous?.userId != next.userId) {
      Future.microtask(() {
        ref.invalidateSelf();
      });
    }
  });

  return ChangeRequestListNotifier(repository, bsRepository);
});

/// Provider for single charging station CR detail
final changeRequestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, changeRequestId) async {
  final repository = ref.watch(changeRequestRepositoryProvider);
  return repository.getChangeRequest(changeRequestId);
});

/// Provider for single battery swap CR detail
final batterySwapChangeRequestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, changeRequestId) async {
  final repository = ref.watch(batterySwapChangeRequestRepositoryProvider);
  return repository.getChangeRequest(changeRequestId);
});