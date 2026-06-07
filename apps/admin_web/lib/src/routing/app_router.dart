import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/unified_change_requests_screen.dart';
import '../screens/change_request_detail_screen.dart';
import '../screens/verification_tasks_list_screen.dart';
import '../screens/verification_task_detail_screen.dart';
import '../screens/issues_list_screen.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/unified_trust_dashboard_screen.dart';
import '../screens/audit_query_screen.dart';
import '../screens/station_audit_screen.dart';
import '../screens/change_request_audit_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/collaborator_management_screen.dart';
import '../screens/collaborator_detail_screen.dart';
import '../screens/contract_detail_screen.dart';
import '../screens/unified_stations_list_screen.dart';
import '../screens/station_detail_screen.dart';
import '../screens/create_station_screen.dart';
import '../screens/csv_import_screen.dart';
import '../screens/battery_swap_cr_detail_screen.dart';
import '../screens/battery_swap_station_detail_screen.dart';
import '../screens/analytics_dashboard_screen.dart';
import '../screens/collaborator_performance_screen.dart';
import '../screens/collaborator_performance_detail_screen.dart';
import '../screens/registration_requests_list_screen.dart';
import '../screens/registration_request_detail_screen.dart';
import '../models/admin_station.dart';
import '../screens/loyalty/loyalty_dashboard_screen.dart';
import '../screens/loyalty/rating_moderation_screen.dart';
import '../screens/loyalty/user_loyalty_list_screen.dart';
import '../screens/loyalty/user_loyalty_detail_screen.dart';
import '../screens/loyalty/voucher_management_screen.dart';
import '../screens/loyalty/voucher_redemptions_screen.dart';
import '../screens/battery_swap/create_battery_swap_station_screen.dart';
import '../screens/battery_swap/battery_swap_csv_import_screen.dart';

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
        builder: (_, __) => const UnifiedChangeRequestsScreen(),
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
        path: '/stations',
        builder: (_, __) => const UnifiedStationsListScreen(),
      ),
      GoRoute(
        path: '/stations/trust',
        builder: (context, state) {
          final stationId = state.uri.queryParameters['stationId'];
          return UnifiedTrustDashboardScreen(stationId: stationId);
        },
      ),
      GoRoute(
        path: '/stations/create',
        builder: (context, state) {
          final station = state.extra as AdminStation?;
          return CreateStationScreen(station: station);
        },
      ),
      GoRoute(
        path: '/stations/import-csv',
        builder: (_, __) => const CsvImportScreen(),
      ),
      GoRoute(
        path: '/stations/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StationDetailScreen(id: id);
        },
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
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/collaborators',
        builder: (_, __) => const CollaboratorManagementScreen(),
      ),
      // Collaborator Performance - NOTE: must come BEFORE /collaborators/:id to avoid matching "performance" as :id
      GoRoute(
        path: '/collaborators/performance',
        builder: (_, __) => const CollaboratorPerformanceScreen(),
      ),
      GoRoute(
        path: '/collaborators/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CollaboratorDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/collaborators/:id/performance',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CollaboratorPerformanceDetailScreen(collaboratorId: id);
        },
      ),
      GoRoute(
        path: '/contracts/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ContractDetailScreen(id: id);
        },
      ),
      // Battery Swap routes (detail screens remain, list is under unified screens)
      GoRoute(
        path: '/battery-swap/change-requests/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BatterySwapCRDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/battery-swap/stations/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BatterySwapStationDetailScreen(id: id);
        },
      ),
      GoRoute(
        path: '/battery-swap/stations/create',
        builder: (_, __) => const CreateBatterySwapStationScreen(),
      ),
      GoRoute(
        path: '/battery-swap/stations/import-csv',
        builder: (_, __) => const BatterySwapCsvImportScreen(),
      ),
      // Battery Swap Trust (individual station via query param)
      GoRoute(
        path: '/battery-swap/trust',
        builder: (context, state) {
          final stationId = state.uri.queryParameters['stationId'];
          return UnifiedTrustDashboardScreen(batterySwapStationId: stationId);
        },
      ),
      // Analytics Dashboard
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const AnalyticsDashboardScreen(),
      ),
      // Registration Requests
      GoRoute(
        path: '/registration-requests',
        builder: (_, __) => const RegistrationRequestsListScreen(),
      ),
      GoRoute(
        path: '/registration-requests/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RegistrationRequestDetailScreen(id: id);
        },
      ),
      // Loyalty routes
      GoRoute(
        path: '/loyalty',
        builder: (_, __) => const LoyaltyDashboardScreen(),
      ),
      GoRoute(
        path: '/loyalty/ratings',
        builder: (_, __) => const RatingModerationScreen(),
      ),
      GoRoute(
        path: '/loyalty/users',
        builder: (_, __) => const UserLoyaltyListScreen(),
      ),
      GoRoute(
        path: '/loyalty/users/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserLoyaltyDetailScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/loyalty/vouchers',
        builder: (_, __) => const VoucherManagementScreen(),
      ),
      GoRoute(
        path: '/loyalty/vouchers/redemptions',
        builder: (_, __) => const VoucherRedemptionsScreen(),
      ),
    ],
  );
});

