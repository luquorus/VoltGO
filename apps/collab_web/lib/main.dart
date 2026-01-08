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
        // Setup AuthService
        authServiceProvider.overrideWith((ref) {
          final dio = ref.read(dioClientProvider(baseUrl));
          return AuthService(dio);
        }),
      ],
      child: const CollabWebApp(),
    ),
  );
}

class CollabWebApp extends ConsumerWidget {
  const CollabWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'VoltGo - Collaborator Web',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

