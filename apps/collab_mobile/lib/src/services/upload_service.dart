import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../models/verification_task.dart';

/// Upload Service for Evidence Photos
class UploadService {
  final CollaboratorMobileApiClient apiClient;
  final Dio dio;

  UploadService({
    required this.apiClient,
    required this.dio,
  });

  /// Presign upload request
  Future<PresignUploadResponse> presignUpload({String? contentType}) async {
    try {
      final response = await apiClient.presignUpload(contentType: contentType);
      return PresignUploadResponse.fromJson(response);
    } on ApiError catch (e) {
      throw Exception('Failed to get presigned URL: ${e.message}');
    } on DioException catch (e) {
      final errorMessage = e.response?.data is Map
          ? (e.response!.data as Map<String, dynamic>)['message'] ?? e.message
          : e.message;
      throw Exception('Failed to get presigned URL: $errorMessage');
    } catch (e) {
      throw Exception('Failed to get presigned URL: $e');
    }
  }

  /// Upload file bytes to presigned URL (for web)
  Future<void> uploadFileBytes({
    required String uploadUrl,
    required Uint8List fileBytes,
    required String contentType,
    required Function(double progress) onProgress,
    int maxRetries = 3,
  }) async {
    int retries = 0;
    
    while (retries < maxRetries) {
      try {
        final response = await dio.put(
          uploadUrl,
          data: fileBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
            },
            validateStatus: (status) => status! < 500,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              onProgress(progress);
            }
          },
        );
        
        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          return;
        } else {
          throw Exception('Upload failed with status: ${response.statusCode}');
        }
      } on DioException catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception('Upload failed after $maxRetries retries: ${e.message}');
        }
        await Future.delayed(Duration(seconds: retries));
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: retries));
      }
    }
  }

  /// Upload file to presigned URL with progress tracking (for mobile)
  Future<void> uploadFile({
    required String uploadUrl,
    required File file,
    required String contentType,
    required Function(double progress) onProgress,
    int maxRetries = 3,
  }) async {
    int retries = 0;
    
    while (retries < maxRetries) {
      try {
        final fileBytes = await file.readAsBytes();
        
        final response = await dio.put(
          uploadUrl,
          data: fileBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
            },
            validateStatus: (status) => status! < 500, // Accept 2xx, 3xx, 4xx
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              onProgress(progress);
            }
          },
        );
        
        // Check if upload was successful (2xx status)
        if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
          // Success
        } else {
          throw Exception('Upload failed with status: ${response.statusCode}');
        }
        
        return; // Success
      } on DioException catch (e) {
        retries++;
        if (retries >= maxRetries) {
          throw Exception('Upload failed after $maxRetries retries: ${e.message}');
        }
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: retries));
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: retries));
      }
    }
  }

  /// Submit evidence after upload
  Future<VerificationTask> submitEvidence({
    required String taskId,
    required String photoObjectKey,
    String? note,
  }) async {
    try {
      final response = await apiClient.submitEvidence(
        taskId: taskId,
        photoObjectKey: photoObjectKey,
        note: note,
      );
      return VerificationTask.fromJson(response);
    } catch (e) {
      throw Exception('Failed to submit evidence: $e');
    }
  }
}

/// Presign Upload Response
class PresignUploadResponse {
  final String objectKey;
  final String uploadUrl;
  final DateTime expiresAt;

  PresignUploadResponse({
    required this.objectKey,
    required this.uploadUrl,
    required this.expiresAt,
  });

  factory PresignUploadResponse.fromJson(Map<String, dynamic> json) {
    return PresignUploadResponse(
      objectKey: json['objectKey'] as String,
      uploadUrl: json['uploadUrl'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

