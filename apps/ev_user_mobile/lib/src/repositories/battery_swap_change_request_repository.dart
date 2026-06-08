import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

/// Repository for battery swap station change request operations
class BatterySwapChangeRequestRepository {
  final EvUserMobileApiClient _apiClient;

  BatterySwapChangeRequestRepository(this._apiClient);

  /// Create a new battery swap change request
  Future<Map<String, dynamic>> createChangeRequest(Map<String, dynamic> data) async {
    try {
      return await _apiClient.createBatterySwapChangeRequest(data);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create battery swap change request: $e');
    }
  }

  /// Get list of battery swap change requests
  Future<List<Map<String, dynamic>>> getChangeRequests() async {
    try {
      final response = await _apiClient.getBatterySwapChangeRequests();
      return (response as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get battery swap change requests: $e');
    }
  }

  /// Get battery swap change request by ID
  Future<Map<String, dynamic>> getChangeRequest(String id) async {
    try {
      return await _apiClient.getBatterySwapChangeRequest(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get battery swap change request: $e');
    }
  }

  /// Submit a battery swap change request
  Future<Map<String, dynamic>> submitChangeRequest(String id) async {
    try {
      return await _apiClient.submitBatterySwapChangeRequest(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to submit battery swap change request: $e');
    }
  }
}
