import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_api/shared_api.dart';
import 'package:dio/dio.dart';
import 'src/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  final baseUrl = dotenv.get('BASE_URL', fallback: 'http://localhost:8080');
  
  runApp(
    ProviderScope(
      overrides: [
        // Initialize ApiClientFactory
        apiClientFactoryProvider.overrideWith((ref) {
          return ApiClientFactory.create(ref, baseUrl: baseUrl);
        }),
        // Keep AuthService for backward compatibility (will migrate to ApiClientFactory)
        authServiceProvider.overrideWith((ref) {
          final dio = ref.read(dioClientProvider(baseUrl));
          return AuthService(dio);
        }),
      ],
      child: const EvUserMobileApp(),
    ),
  );
}

class EvUserMobileApp extends ConsumerWidget {
  const EvUserMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'VoltGo - EV User',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

