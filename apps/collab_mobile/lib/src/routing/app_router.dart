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
      
      // Collab app guard: only COLLABORATOR
      if (role != 'COLLABORATOR') {
        return '/forbidden';
      }
      
      // Redirect /home to /tasks
      if (location == '/home') {
        return '/tasks';
      }
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const TaskListScreen()),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId'] ?? '';
          return TaskDetailScreen(taskId: taskId);
        },
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
    ],
  );
});

