import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/route_models.dart';

class GeocodingService {
  final Dio _dio;
  final Map<String, List<PlaceSuggestion>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheDuration = Duration(seconds: 30);

  GeocodingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              headers: kIsWeb
                  ? {}
                  : {'User-Agent': 'VoltGoApp/1.0 (contact@voltgo.com)'},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((e) => now.difference(e.value) > _cacheDuration)
        .map((e) => e.key)
        .toList();
    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final cacheKey = query.toLowerCase().trim();
    _cleanExpiredCache();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'q': encodedQuery,
          'format': 'json',
          'addressdetails': 1,
          'limit': 5,
        },
      );

      final results = response.data as List<dynamic>;

      if (results.isNotEmpty) {
        final suggestions = results
            .map((e) => PlaceSuggestion.fromNominatimJson(e as Map<String, dynamic>))
            .toList();
        _cache[cacheKey] = suggestions;
        _cacheTimestamps[cacheKey] = DateTime.now();
        return suggestions;
      }

      return [];
    } on DioException {
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<PlaceSuggestion?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        '/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': 1,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return PlaceSuggestion(
          displayName: data['display_name'] as String? ?? '',
          lat: double.parse(data['lat'] as String),
          lng: double.parse(data['lon'] as String),
          type: data['type'] as String?,
          importance: null,
        );
      }

      return null;
    } on DioException {
      return null;
    } catch (e) {
      return null;
    }
  }
}
