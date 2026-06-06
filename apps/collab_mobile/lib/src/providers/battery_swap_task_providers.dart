import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../models/battery_swap_verification_task.dart';

/// Battery Swap Task Repository Provider
final batterySwapTaskRepositoryProvider =
    Provider<BatterySwapTaskRepository>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('API client factory not initialized');
  }
  return BatterySwapTaskRepository(apiFactory.collabMobile);
});

/// Battery Swap Tasks Provider (filtered by BATTERY_SWAP)
final swapTasksProvider =
    FutureProvider<List<BatterySwapVerificationTask>>((ref) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.getSwapTasks();
});

/// Battery Swap Task Detail Provider
final swapTaskDetailProvider =
    FutureProvider.family<BatterySwapVerificationTask, String>((ref, taskId) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.getSwapTask(taskId);
});

/// Battery Swap Check-in Provider
final batterySwapCheckInProvider =
    Provider.family<Future<BatterySwapVerificationTask>, BatterySwapCheckInParams>(
        (ref, params) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.checkIn(
    taskId: params.taskId,
    lat: params.lat,
    lng: params.lng,
    batteryInventoryCount: params.batteryInventoryCount,
    pileCount: params.pileCount,
    slotCount: params.slotCount,
    isOperatingHoursAccurate: params.isOperatingHoursAccurate,
    parkingFee: params.parkingFee,
    notes: params.notes,
  );
});

/// Battery Swap Submit Evidence Provider
final batterySwapSubmitEvidenceProvider =
    Provider.family<Future<BatterySwapVerificationTask>, BatterySwapSubmitEvidenceParams>(
        (ref, params) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.submitEvidence(
    taskId: params.taskId,
    imageBytes: params.imageBytes,
    contentType: params.contentType,
    evidenceType: params.evidenceType,
    note: params.note,
  );
});

/// Evidence image URL provider
final evidenceViewUrlProvider =
    FutureProvider.family<String, String>((ref, objectKey) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.getEvidenceViewUrl(objectKey);
});

/// Battery Swap Check-in Parameters
class BatterySwapCheckInParams {
  final String taskId;
  final double lat;
  final double lng;
  final int batteryInventoryCount;
  final int pileCount;
  final int slotCount;
  final bool isOperatingHoursAccurate;
  final int? parkingFee;
  final String? notes;

  BatterySwapCheckInParams({
    required this.taskId,
    required this.lat,
    required this.lng,
    required this.batteryInventoryCount,
    required this.pileCount,
    required this.slotCount,
    required this.isOperatingHoursAccurate,
    this.parkingFee,
    this.notes,
  });
}

class BatterySwapSubmitEvidenceParams {
  final String taskId;
  final Uint8List imageBytes;
  final String contentType;
  final String? evidenceType;
  final String? note;

  BatterySwapSubmitEvidenceParams({
    required this.taskId,
    required this.imageBytes,
    required this.contentType,
    this.evidenceType,
    this.note,
  });
}

/// Battery Swap Task Repository
class BatterySwapTaskRepository {
  final CollaboratorMobileApiClient apiClient;

  BatterySwapTaskRepository(this.apiClient);

  /// Get battery swap verification tasks (tasks for BATTERY_SWAP stations)
  Future<List<BatterySwapVerificationTask>> getSwapTasks({
    List<String>? statuses,
  }) async {
    try {
      final response = await apiClient.getTasks(status: statuses);

      // Filter for battery swap tasks only
      final allTasks = (response as List)
          .map((json) =>
              BatterySwapVerificationTask.fromJson(json as Map<String, dynamic>))
          .where((task) => task.isBatterySwapStation)
          .toList();

      return allTasks;
    } catch (e) {
      print('Error fetching battery swap tasks: $e');
      throw Exception('Failed to fetch battery swap tasks: $e');
    }
  }

  /// Get a specific battery swap task
  Future<BatterySwapVerificationTask> getSwapTask(String taskId) async {
    try {
      // Get all tasks and find the specific one
      final allTasks = await getSwapTasks();
      final task = allTasks
          .cast<BatterySwapVerificationTask?>()
          .firstWhere((t) => t?.id == taskId, orElse: () => null);

      if (task == null) {
        throw ApiError(
          traceId: '',
          code: 'NOT_FOUND',
          message: 'Task not found.',
          timestamp: DateTime.now(),
        );
      }
      return task;
    } catch (e) {
      if (e is ApiError) rethrow;
      throw Exception('Failed to fetch task: $e');
    }
  }

  /// Battery swap check-in with inventory data
  Future<BatterySwapVerificationTask> checkIn({
    required String taskId,
    required double lat,
    required double lng,
    required int batteryInventoryCount,
    required int pileCount,
    required int slotCount,
    required bool isOperatingHoursAccurate,
    int? parkingFee,
    String? notes,
  }) async {
    try {
      // Map pileCount to actualTotalBatteries as fallback for backend compatibility
      // The backend only accepts: lat, lng, deviceNote, actualTotalBatteries, actualAvailableBatteries, observedAvgChargePowerKw
      final response = await apiClient.batterySwapCheckIn(
        taskId: taskId,
        lat: lat,
        lng: lng,
        actualTotalBatteries: batteryInventoryCount,
        deviceNote: notes,
      );

      return BatterySwapVerificationTask.fromJson(response);
    } catch (e) {
      if (e is ApiError) rethrow;
      throw Exception('Check-in failed: $e');
    }
  }

  /// Submit evidence for battery swap verification
  Future<BatterySwapVerificationTask> submitEvidence({
    required String taskId,
    required Uint8List imageBytes,
    required String contentType,
    String? evidenceType,
    String? note,
  }) async {
    try {
      final presign = await apiClient.presignUpload(contentType: contentType);
      final objectKey = presign['objectKey'] as String;
      final uploadUrl = presign['uploadUrl'] as String;

      try {
        await Dio().put<dynamic>(
          uploadUrl,
          data: imageBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
            },
          ),
        );
      } on DioException catch (e) {
        throw ApiError(
          traceId: '',
          code: 'UPLOAD_FAILED',
          message:
              'Image upload failed. Check your connection and try again. (${e.message ?? "unknown error"})',
          timestamp: DateTime.now(),
        );
      }

      final trimmedNote = note?.trim();
      final response = await apiClient.batterySwapSubmitEvidence(
        taskId: taskId,
        photoObjectKey: objectKey,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
      );

      return BatterySwapVerificationTask.fromJson(response);
    } catch (e) {
      if (e is ApiError) rethrow;
      throw Exception('Failed to submit evidence: $e');
    }
  }

  Future<String> getEvidenceViewUrl(String objectKey) async {
    try {
      final response = await apiClient.presignView(objectKey: objectKey);
      return response['viewUrl'] as String;
    } catch (e) {
      if (e is ApiError) rethrow;
      throw Exception('Could not load evidence image: $e');
    }
  }
}
