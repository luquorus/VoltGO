import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/forbidden_screen.dart';

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final role = authState.role;
      final location = state.uri.path;
      
      // Public routes
      if (location == '/splash' || location == '/login' || location == '/register') {
        return null;
      }
      
      // Check authentication
      if (!isAuthenticated) {
        return '/login';
      }
      
      // Check role guard for EV app
      if (role != 'EV_USER' && role != 'PROVIDER') {
        return '/forbidden';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
    ],
  );
});

