import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/contract.dart';

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

