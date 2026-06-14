import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_api/shared_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'src/routing/app_router.dart';
import 'src/theme/admin_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize file_picker for web to prevent LateInitializationError
  if (kIsWeb) {
    FilePicker.platform;
  }

  final baseUrl = dotenv.get('BASE_URL', fallback: 'http://localhost:8080');

  runApp(
    ProviderScope(
      overrides: [
        // Setup AuthService
        authServiceProvider.overrideWith((ref) {
          final dio = ref.read(dioClientProvider(baseUrl));
          return AuthService(dio);
        }),
        // Setup ApiClientFactory
        apiClientFactoryProvider.overrideWith((ref) {
          return ApiClientFactory.create(
            ref,
            baseUrl: baseUrl,
            // Auto-logout on 401: clear local session so the router
            // bounces the user back to /login instead of showing
            // EVS-0401 as a regular error.
            onUnauthorized: () {
              try {
                ref.read(authStateNotifierProvider.notifier).logout();
              } catch (_) {
                // Interceptor context: never let this callback break
                // request rejection.
              }
            },
          );
        }),
      ],
      child: const AdminWebApp(),
    ),
  );
}

class AdminWebApp extends ConsumerWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'VoltGo - Admin Portal',
      theme: AdminTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

