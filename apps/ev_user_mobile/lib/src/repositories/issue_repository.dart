import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

/// Issue Repository using OpenAPI client
class IssueRepository {
  final EvUserMobileApiClient _apiClient;

  IssueRepository(this._apiClient);

  /// Report an issue on a station
  /// Returns IssueResponse
  Future<Map<String, dynamic>> reportIssue({
    required String stationId,
    required String category,
    required String description,
  }) async {
    try {
      return await _apiClient.reportIssue(
        stationId: stationId,
        category: category,
        description: description,
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get my reported issues
  /// Returns List<IssueResponse>
  Future<List<dynamic>> getMyIssues() async {
    try {
      return await _apiClient.getMyIssues();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        traceId: '',
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }
}

