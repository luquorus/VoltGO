import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

/// Repository for change request operations
class ChangeRequestRepository {
  final EvUserMobileApiClient _apiClient;

  ChangeRequestRepository(this._apiClient);

  /// Create a new change request
  Future<Map<String, dynamic>> createChangeRequest(Map<String, dynamic> data) async {
    try {
      return await _apiClient.createChangeRequest(data);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create change request: $e');
    }
  }

  /// Get list of change requests
  Future<List<Map<String, dynamic>>> getChangeRequests() async {
    try {
      final response = await _apiClient.getChangeRequests();
      return (response as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get change requests: $e');
    }
  }

  /// Get change request by ID
  Future<Map<String, dynamic>> getChangeRequest(String id) async {
    try {
      return await _apiClient.getChangeRequest(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get change request: $e');
    }
  }

  /// Submit a change request
  Future<Map<String, dynamic>> submitChangeRequest(String id) async {
    try {
      return await _apiClient.submitChangeRequest(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to submit change request: $e');
    }
  }

  /// Get presigned upload URL for image upload
  Future<Map<String, dynamic>> presignUpload({String? contentType}) async {
    try {
      return await _apiClient.presignUpload(contentType: contentType);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get presigned upload URL: $e');
    }
  }

  /// Update change request image URLs
  Future<Map<String, dynamic>> updateChangeRequestImageUrls(String id, List<String> imageUrls) async {
    try {
      return await _apiClient.updateChangeRequest(id, {'imageUrls': imageUrls});
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update change request image URLs: $e');
    }
  }
}

