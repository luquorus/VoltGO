import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

export 'package:shared_network/shared_network.dart' show ApiError;

/// Repository for booking operations
class BookingRepository {
  final EvUserMobileApiClient _apiClient;

  BookingRepository(this._apiClient);

  /// Create a new booking
  Future<Map<String, dynamic>> createBooking({
    required String stationId,
    required String chargerUnitId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      return await _apiClient.createBooking(
        stationId: stationId,
        chargerUnitId: chargerUnitId,
        startTime: startTime.toUtc().toIso8601String(),
        endTime: endTime.toUtc().toIso8601String(),
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Get paginated list of bookings
  Future<Map<String, dynamic>> getBookings({
    int page = 0,
    int size = 20,
  }) async {
    try {
      return await _apiClient.getBookings(page: page, size: size);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get bookings: $e');
    }
  }

  /// Get booking by ID
  Future<Map<String, dynamic>> getBooking(String id) async {
    try {
      return await _apiClient.getBooking(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }

  /// Cancel a booking
  Future<Map<String, dynamic>> cancelBooking(String id) async {
    try {
      return await _apiClient.cancelBooking(id);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  /// Create payment intent
  Future<Map<String, dynamic>> createPaymentIntent(String bookingId) async {
    try {
      return await _apiClient.createPaymentIntent(bookingId);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  /// Simulate payment success
  Future<Map<String, dynamic>> simulatePaymentSuccess(String intentId) async {
    try {
      return await _apiClient.simulatePaymentSuccess(intentId);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to simulate payment success: $e');
    }
  }

  /// Simulate payment failure
  Future<Map<String, dynamic>> simulatePaymentFail(String intentId) async {
    try {
      return await _apiClient.simulatePaymentFail(intentId);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to simulate payment failure: $e');
    }
  }
}

