import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/login_screen.dart';
import '../screens/simulator_screen.dart';
import '../screens/station_display_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/display',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final location = state.uri.path;

      // Public routes — no auth required
      if (location == '/display') {
        return null;
      }

      if (location == '/login') {
        return null;
      }

      if (!isAuthenticated) {
        return '/login';
      }

      return null;
    },
    routes: [
      // Public display screen (no auth)
      GoRoute(path: '/display', builder: (_, __) => const StationDisplayScreen()),
      // Operator login
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      // Full simulator (requires auth)
      GoRoute(path: '/simulator', builder: (_, __) => const SimulatorScreen()),
    ],
  );
});
