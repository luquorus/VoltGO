import 'package:flutter/painting.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/contract.dart';
import '../models/collaborator_profile.dart';

/// Provider for contracts list by collaborator ID
final contractsByCollaboratorProvider = FutureProvider.family<List<Contract>, String>((ref, collaboratorId) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getContracts(collaboratorId: collaboratorId);

  return (response as List).map((json) => Contract.fromJson(json as Map<String, dynamic>)).toList();
});

/// Provider for a single contract by ID
final contractProvider = FutureProvider.family<Contract, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getContract(id);
  return Contract.fromJson(response);
});

// =============================================================================
// All Collaborators with Contracts (for unified collaborator management)
// =============================================================================

/// Provider for fetching all collaborators with their contracts
/// Used by the unified Collaborator Management screen
final allCollaboratorsProvider = FutureProvider<List<CollaboratorWithContracts>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  // Fetch all collaborators (page 0, large size to get all)
  final response = await factory.admin.getCollaborators(page: 0, size: 1000);
  final collaborators = (response['content'] as List)
      .map((json) => CollaboratorProfile.fromJson(json as Map<String, dynamic>))
      .toList();

  // Fetch contracts for each collaborator in parallel
  final futures = collaborators.map((collab) async {
    final contractsResponse = await factory.admin.getContracts(collaboratorId: collab.id);
    final contracts = (contractsResponse as List)
        .map((json) => Contract.fromJson(json as Map<String, dynamic>))
        .toList();
    return CollaboratorWithContracts(profile: collab, contracts: contracts);
  });

  return await Future.wait(futures);
});

/// Extended collaborator info combining profile + contract status
class CollaboratorWithContracts {
  final CollaboratorProfile profile;
  final List<Contract> contracts;

  CollaboratorWithContracts({required this.profile, required this.contracts});

  bool get hasActiveContract {
    return profile.hasActiveContract == true &&
        contracts.any((c) => c.status == ContractStatus.active && c.isEffectivelyActive != false);
  }

  Contract? get latestContract {
    if (contracts.isEmpty) return null;
    return contracts.reduce((a, b) =>
        (a.createdAt ?? DateTime(1970)).isAfter(b.createdAt ?? DateTime(1970)) ? a : b);
  }

  Contract? get latestActiveContract {
    final active = contracts.where((c) =>
        c.status == ContractStatus.active && c.isEffectivelyActive != false);
    if (active.isEmpty) return null;
    return active.reduce((a, b) =>
        (a.endDate ?? DateTime(1970)).isAfter(b.endDate ?? DateTime(1970)) ? a : b);
  }

  NoContractReason? get noContractReason {
    if (hasActiveContract) return null;
    if (contracts.isEmpty) return NoContractReason.neverHadContract;
    final latest = latestContract;
    if (latest == null) return NoContractReason.neverHadContract;
    if (latest.status == ContractStatus.terminated) return NoContractReason.contractTerminated;
    if (latest.status == ContractStatus.active && latest.isEffectivelyActive == false) {
      return NoContractReason.contractExpired;
    }
    return NoContractReason.neverHadContract;
  }
}

/// Reasons why a collaborator has no active contract
enum NoContractReason {
  neverHadContract('Chưa có hợp đồng', Color(0xFFFF9800)),
  contractExpired('Hết hạn hợp đồng', Color(0xFFF44336)),
  contractTerminated('Hủy hợp đồng', Color(0xFFFF5722));

  final String label;
  final Color color;

  const NoContractReason(this.label, this.color);
}

// =============================================================================
// Contract Action Notifiers (create, terminate)
// =============================================================================

/// Notifier for creating a contract with notification
class CreateContractNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CreateContractNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> create({
    required String collaboratorId,
    String? region,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.createContract(
        CreateContractDTO(
          collaboratorId: collaboratorId,
          region: region,
          startDate: startDate,
          endDate: endDate,
          note: note,
        ).toJson(),
      );

      // Invalidate related providers to refresh data
      ref.invalidate(allCollaboratorsProvider);
      ref.invalidate(contractsByCollaboratorProvider(collaboratorId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final createContractProvider = StateNotifierProvider<CreateContractNotifier, AsyncValue<void>>((ref) {
  return CreateContractNotifier(ref);
});

/// Notifier for terminating a contract with notification
class TerminateContractNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  TerminateContractNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> terminate({
    required String contractId,
    required String collaboratorId,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.terminateContract(contractId, reason: reason);

      // Invalidate related providers to refresh data
      ref.invalidate(allCollaboratorsProvider);
      ref.invalidate(contractsByCollaboratorProvider(collaboratorId));
      ref.invalidate(contractProvider(contractId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final terminateContractProvider = StateNotifierProvider<TerminateContractNotifier, AsyncValue<void>>((ref) {
  return TerminateContractNotifier(ref);
});

/// Notifier for updating a contract
class UpdateContractNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  UpdateContractNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> update({
    required String contractId,
    required String collaboratorId,
    String? region,
    DateTime? startDate,
    DateTime? endDate,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.updateContract(
        contractId,
        UpdateContractDTO(
          region: region,
          startDate: startDate,
          endDate: endDate,
          note: note,
        ).toJson(),
      );

      // Invalidate related providers to refresh data
      ref.invalidate(allCollaboratorsProvider);
      ref.invalidate(contractsByCollaboratorProvider(collaboratorId));
      ref.invalidate(contractProvider(contractId));

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final updateContractProvider = StateNotifierProvider<UpdateContractNotifier, AsyncValue<void>>((ref) {
  return UpdateContractNotifier(ref);
});

/// Notifier for deleting a collaborator
class DeleteCollaboratorNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  DeleteCollaboratorNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> delete(String collaboratorId) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.deleteCollaborator(collaboratorId);

      // Invalidate all collaborator data to refresh the tabs
      ref.invalidate(allCollaboratorsProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final deleteCollaboratorProvider = StateNotifierProvider<DeleteCollaboratorNotifier, AsyncValue<void>>((ref) {
  return DeleteCollaboratorNotifier(ref);
});
