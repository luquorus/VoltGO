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
import '../screens/edit_profile_screen.dart';
import '../screens/contracts_screen.dart';
import '../screens/swap_verification_tasks_screen.dart';
import '../screens/swap_kpi_screen.dart';
import '../screens/notifications_screen.dart';

/// Route paths for Collaborator Web
class CollabRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String forbidden = '/forbidden';
  
  // Charging Station routes
  static const String chargingStation = '/charging-station';
  static const String chargingStationHistory = '/charging-station/history';
  static const String chargingStationKpi = '/charging-station/kpi';

  // Swap Station routes
  static const String swapStation = '/swap-station';
  static const String swapStationKpi = '/swap-station/kpi';

  // Profile/Account routes
  static const String profile = '/me/profile';
  static const String contracts = '/me/contracts';
  static const String notifications = '/notifications';
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
      
      // Redirect root and /home to /charging-station
      if (location == '/' || location == '/home') {
        return CollabRoutes.chargingStation;
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
      
      // Charging Station routes
      GoRoute(
        path: CollabRoutes.chargingStation,
        builder: (_, __) => const TasksScreen(),
      ),
      GoRoute(
        path: CollabRoutes.chargingStationHistory,
        builder: (_, __) => const TaskHistoryScreen(),
      ),
      GoRoute(
        path: CollabRoutes.chargingStationKpi,
        builder: (_, __) => const TaskKPIScreen(),
      ),
      // Swap Station routes
      GoRoute(
        path: CollabRoutes.swapStation,
        builder: (_, __) => const SwapVerificationTasksScreen(),
      ),
      GoRoute(
        path: CollabRoutes.swapStationKpi,
        builder: (_, __) => const SwapKPIScreen(),
      ),
      // Profile/Account routes
      GoRoute(
        path: CollabRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/me/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: CollabRoutes.contracts,
        builder: (_, __) => const ContractsScreen(),
      ),
      // Notifications route
      GoRoute(
        path: CollabRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
    ],
  );
});
