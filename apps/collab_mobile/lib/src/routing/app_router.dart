import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/task_list_screen.dart';
import '../screens/task_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/swap_verification_task_detail_screen.dart';
import '../screens/swap_task_list_screen.dart';
import '../screens/registration_form_screen.dart';
import '../screens/registration_pending_screen.dart';
import '../screens/notifications_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final role = authState.role;
      final location = state.uri.path;
      
      if (location == '/splash' || location == '/login' || location == '/register') {
        return null;
      }
      
      if (!isAuthenticated) {
        return '/login';
      }

      // Allow authenticated users to access registration flow pages (even if they don't have full profile yet)
      if (location == '/registration-form' || location == '/registration-pending') {
        return null;
      }

      // Collab app guard: only COLLABORATOR with full profile can access task screens
      if (role != 'COLLABORATOR') {
        return '/forbidden';
      }

      // Collab who hasn't submitted registration form must complete it first
      if (!authState.registrationSubmitted) {
        // Redirect to registration form (or pending) - do NOT allow task screens
        if (location != '/registration-form' && location != '/registration-pending') {
          return '/registration-form';
        }
      }

      // Redirect /home to /charging-station
      if (location == '/home') {
        return '/charging-station';
      }
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/charging-station', builder: (_, __) => const TaskListScreen()),
      GoRoute(
        path: '/charging-station/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId'] ?? '';
          return TaskDetailScreen(taskId: taskId);
        },
      ),
      // Swap Station verification routes
      GoRoute(
        path: '/swap-station',
        builder: (_, __) => const SwapTaskListScreen(),
      ),
      GoRoute(
        path: '/swap-station/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId'] ?? '';
          return SwapVerificationTaskDetailScreen(taskId: taskId);
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
      // Registration flow
      GoRoute(path: '/registration-form', builder: (_, __) => const RegistrationFormScreen()),
      GoRoute(
        path: '/registration-pending',
        builder: (context, state) {
          final requestId = state.extra as String? ?? '';
          return RegistrationPendingScreen(requestId: requestId);
        },
      ),
      // Notifications
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    ],
  );
});

