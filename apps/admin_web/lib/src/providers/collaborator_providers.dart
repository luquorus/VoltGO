import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/collaborator_profile.dart';
import '../models/pagination_response.dart';

/// Provider for collaborator pagination state
final collaboratorPaginationProvider = StateProvider<CollaboratorPagination>((ref) {
  return CollaboratorPagination(page: 0, size: 20);
});

/// Pagination state for collaborators
class CollaboratorPagination {
  final int page;
  final int size;

  CollaboratorPagination({
    required this.page,
    required this.size,
  });

  CollaboratorPagination copyWith({
    int? page,
    int? size,
  }) {
    return CollaboratorPagination(
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }
}

/// Provider for collaborators list with pagination
final collaboratorsProvider = FutureProvider<PaginationResponse<CollaboratorProfile>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final pagination = ref.watch(collaboratorPaginationProvider);

  final response = await factory.admin.getCollaborators(
    page: pagination.page,
    size: pagination.size,
  );

  return PaginationResponse<CollaboratorProfile>.fromJson(
    response,
    (json) => CollaboratorProfile.fromJson(json as Map<String, dynamic>),
  );
});

/// Provider for a single collaborator by ID
final collaboratorProvider = FutureProvider.family<CollaboratorProfile, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getCollaborator(id);
  return CollaboratorProfile.fromJson(response);
});

