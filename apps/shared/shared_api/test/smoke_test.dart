import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';

/// Smoke test script for API endpoints
/// 
/// Usage:
/// ```bash
/// flutter test apps/shared/shared_api/test/smoke_test.dart --dart-define=API_BASE_URL=http://localhost:8080
/// ```
/// 
/// Or with authentication token:
/// ```bash
/// flutter test apps/shared/shared_api/test/smoke_test.dart --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=TEST_TOKEN=your_jwt_token
/// ```

void main() async {
  final baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  final testToken = const String.fromEnvironment('TEST_TOKEN', defaultValue: '');

  print('🚀 Starting API smoke tests...');
  print('Base URL: $baseUrl');
  if (testToken.isNotEmpty) {
    print('Using test token: ${testToken.substring(0, 20)}...');
  } else {
    print('⚠️  No test token provided. Some tests may fail.');
  }
  print('');

  final container = ProviderContainer();
  final factory = ApiClientFactory.create(container, baseUrl: baseUrl);

  // If token provided, set auth state
  if (testToken.isNotEmpty) {
    // Note: This assumes auth state can be set directly
    // In real app, use AuthService.login() instead
  }

  int passed = 0;
  int failed = 0;

  // Test 1: EV User Mobile - GET /api/ev/stations
  print('Test 1: EV User Mobile - GET /api/ev/stations');
  try {
    final result = await factory.ev.getStations(
      lat: 21.0285,
      lng: 105.8542,
      radiusKm: 5.0,
      page: 0,
      size: 20,
    );
    print('✅ PASS: Got ${result['content']?.length ?? 0} stations');
    passed++;
  } catch (e) {
    print('❌ FAIL: $e');
    failed++;
  }
  print('');

  // Test 2: Collaborator Mobile - GET /api/collab/mobile/tasks
  print('Test 2: Collaborator Mobile - GET /api/collab/mobile/tasks');
  try {
    final result = await factory.collabMobile.getTasks();
    print('✅ PASS: Got ${result.length} tasks');
    passed++;
  } catch (e) {
    print('❌ FAIL: $e');
    failed++;
  }
  print('');

  // Test 3: Collaborator Web - GET /api/collab/web/tasks
  print('Test 3: Collaborator Web - GET /api/collab/web/tasks');
  try {
    final result = await factory.collabWeb.getTasks(page: 0, size: 20);
    print('✅ PASS: Got ${result['content']?.length ?? 0} tasks (total: ${result['totalElements'] ?? 0})');
    passed++;
  } catch (e) {
    print('❌ FAIL: $e');
    failed++;
  }
  print('');

  // Test 4: Admin Web - GET /api/admin/change-requests
  print('Test 4: Admin Web - GET /api/admin/change-requests');
  try {
    final result = await factory.admin.getChangeRequests();
    print('✅ PASS: Got ${result.length} change requests');
    passed++;
  } catch (e) {
    print('❌ FAIL: $e');
    failed++;
  }
  print('');

  // Summary
  print('=' * 50);
  print('Test Summary:');
  print('✅ Passed: $passed');
  print('❌ Failed: $failed');
  print('Total: ${passed + failed}');
  print('=' * 50);

  container.dispose();
}

