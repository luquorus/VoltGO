import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/task_history_screen.dart';
import '../screens/task_kpi_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/contracts_screen.dart';

/// Route paths for Collaborator Web
class CollabRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String forbidden = '/forbidden';
  
  // Task routes
  static const String tasks = '/tasks';
  static const String taskHistory = '/tasks/history';
  static const String taskKpi = '/tasks/kpi';
  
  // Profile/Account routes
  static const String profile = '/me/profile';
  static const String contracts = '/me/contracts';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: CollabRoutes.splash,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final role = authState.role;
      final location = state.uri.path;
      
      // Allow unauthenticated routes
      if (location == CollabRoutes.splash || location == CollabRoutes.login) {
        return null;
      }
      
      // Redirect to login if not authenticated
      if (!isAuthenticated) {
        return CollabRoutes.login;
      }
      
      // Collaborator web guard: only COLLABORATOR
      if (role != 'COLLABORATOR') {
        return CollabRoutes.forbidden;
      }
      
      // Redirect root and /home to /tasks
      if (location == '/' || location == '/home') {
        return CollabRoutes.tasks;
      }
      
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: CollabRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: CollabRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: CollabRoutes.forbidden,
        builder: (_, __) => const ForbiddenScreen(),
      ),
      
      // Task routes
      GoRoute(
        path: CollabRoutes.tasks,
        builder: (_, __) => const TasksScreen(),
      ),
      GoRoute(
        path: CollabRoutes.taskHistory,
        builder: (_, __) => const TaskHistoryScreen(),
      ),
      GoRoute(
        path: CollabRoutes.taskKpi,
        builder: (_, __) => const TaskKPIScreen(),
      ),
      
      // Profile/Account routes
      GoRoute(
        path: CollabRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: CollabRoutes.contracts,
        builder: (_, __) => const ContractsScreen(),
      ),
    ],
  );
});
