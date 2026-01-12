/// Simple test script for FE-3
/// Run: dart run test_fe3_simple.dart
/// Make sure backend is running at http://localhost:8080

import 'dart:io';

void main() async {
  print('🧪 Testing FE-3: OpenAPI Client Integration\n');

  // Test 1: Backend health
  print('1. Checking backend health...');
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://localhost:8080/healthz'));
    final response = await request.close();
    if (response.statusCode == 200) {
      print('   ✅ Backend is running\n');
    } else {
      print('   ❌ Backend returned status ${response.statusCode}\n');
      exit(1);
    }
    client.close();
  } catch (e) {
    print('   ❌ Backend not running: $e');
    print('   Please start backend: cd infra && docker-compose up -d\n');
    exit(1);
  }

  // Test 2: Login
  print('2. Testing Auth API (Login)...');
  try {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('http://localhost:8080/auth/login'));
    request.headers.contentType = ContentType('application', 'json');
    request.write('{"email":"admin@local","password":"Admin@123"}');
    final response = await request.close();
    final responseBody = await response.transform(const SystemEncoding().decoder).join();
    
    if (response.statusCode == 200) {
      print('   ✅ Login successful\n');
      print('   Response: $responseBody\n');
    } else {
      print('   ❌ Login failed: ${response.statusCode}');
      print('   Response: $responseBody\n');
      exit(1);
    }
    client.close();
  } catch (e) {
    print('   ❌ Login error: $e\n');
    exit(1);
  }

  print('✅ Basic API connectivity test passed!');
  print('\nNext steps:');
  print('1. Run Flutter smoke test:');
  print('   flutter test apps/shared/shared_api/test/smoke_test.dart --dart-define=API_BASE_URL=http://localhost:8080');
  print('\n2. Test in app:');
  print('   - Start any Flutter app');
  print('   - Login with admin@local / Admin@123');
  print('   - Use ApiClientFactory in code');
}

