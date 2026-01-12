import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_api/shared_api.dart';
import 'src/routing/app_router.dart';
import 'src/theme/collab_theme.dart';

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
        // Setup ApiClientFactory
        apiClientFactoryProvider.overrideWith((ref) {
          return ApiClientFactory.create(ref, baseUrl: baseUrl);
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
      debugShowCheckedModeBanner: false,
      theme: CollabTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
