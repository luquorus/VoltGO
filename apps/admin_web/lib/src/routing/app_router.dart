import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/change_requests_screen.dart';
import '../screens/change_request_detail_screen.dart';
import '../screens/verification_tasks_list_screen.dart';
import '../screens/verification_task_detail_screen.dart';
import '../screens/issues_list_screen.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/station_trust_screen.dart';
import '../screens/audit_query_screen.dart';
import '../screens/station_audit_screen.dart';
import '../screens/change_request_audit_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final role = authState.role;
      final location = state.uri.path;
      
      if (location == '/splash' || location == '/login') {
        return null;
      }
      
      if (!isAuthenticated) {
        return '/login';
      }
      
      // Admin web guard: only ADMIN
      if (role != 'ADMIN') {
        return '/forbidden';
      }
      
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
      GoRoute(
        path: '/change-requests',
        builder: (_, __) => const ChangeRequestsScreen(),
      ),
      GoRoute(
        path: '/change-requests/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChangeRequestDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/verification-tasks',
        builder: (_, __) => const VerificationTasksListScreen(),
      ),
      GoRoute(
        path: '/verification-tasks/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VerificationTaskDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/issues',
        builder: (_, __) => const IssuesListScreen(),
      ),
      GoRoute(
        path: '/issues/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return IssueDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/stations/:id/trust',
        builder: (context, state) {
          final stationId = state.pathParameters['id']!;
          return StationTrustScreen(stationId: stationId);
        },
      ),
      GoRoute(
        path: '/stations/trust',
        builder: (context, state) => const StationTrustScreen(),
      ),
      GoRoute(
        path: '/audit',
        builder: (_, __) => const AuditQueryScreen(),
      ),
      GoRoute(
        path: '/audit/stations',
        builder: (_, __) => const StationAuditScreen(),
      ),
      GoRoute(
        path: '/audit/change-requests',
        builder: (_, __) => const ChangeRequestAuditScreen(),
      ),
    ],
  );
});

