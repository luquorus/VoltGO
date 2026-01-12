import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_issue.dart';

/// Issue status filter provider
final issueStatusFilterProvider = StateProvider<IssueStatus?>((ref) => null);

/// Issues list provider
final issuesProvider = FutureProvider<List<AdminIssue>>((ref) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final statusFilter = ref.watch(issueStatusFilterProvider);
  final response = await factory.admin.getIssues(
    status: statusFilter?.name,
  );

  if (response is! List) {
    throw Exception('Invalid response format');
  }

  return (response as List)
      .map((json) => AdminIssue.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Issue detail provider
final issueProvider = FutureProvider.family<AdminIssue, String>((ref, id) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getIssue(id);
  return AdminIssue.fromJson(response);
});

