import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_map_screen.dart';
import '../screens/station_detail_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/create_booking_with_charger_unit_screen.dart';
import '../screens/booking_list_screen.dart';
import '../screens/booking_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/change_request_list_screen.dart';
import '../screens/change_request_detail_screen.dart';
import '../screens/change_request_create_screen.dart';
import '../screens/battery_swap_change_request_detail_screen.dart';
import '../screens/my_issues_screen.dart';
import '../screens/recommendation_screen.dart';
import '../screens/battery_swap_screen.dart';
import '../screens/battery_swap_reservation_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/loyalty_home_screen.dart';
import '../screens/rate_station_screen.dart';
import '../screens/point_history_screen.dart';
import '../screens/badge_collection_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/loyalty/voucher_catalog_screen.dart';
import '../screens/loyalty/my_vouchers_screen.dart';
import '../screens/loyalty/voucher_detail_screen.dart';

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
      if (role != 'EV_USER') {
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
        builder: (context, state) => const HomeMapScreen(),
      ),
      GoRoute(
        path: '/stations/:stationId',
        builder: (context, state) {
          final stationId = state.pathParameters['stationId'] ?? '';
          return StationDetailScreen(stationId: stationId);
        },
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingListScreen(),
      ),
      GoRoute(
        path: '/bookings/create',
        builder: (context, state) {
          final stationId = state.uri.queryParameters['stationId'] ?? '';
          final stationName = state.uri.queryParameters['stationName'];
          return CreateBookingWithChargerUnitScreen(
            stationId: stationId,
            stationName: stationName,
          );
        },
      ),
      GoRoute(
        path: '/bookings/:bookingId',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId'] ?? '';
          return BookingDetailScreen(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-requests',
        builder: (context, state) => const ChangeRequestListScreen(),
      ),
      GoRoute(
        path: '/change-requests/create',
        builder: (context, state) => const ChangeRequestCreateScreen(),
      ),
      GoRoute(
        path: '/change-requests/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ChangeRequestDetailScreen(changeRequestId: id);
        },
      ),
      GoRoute(
        path: '/change-requests/battery-swap/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BatterySwapChangeRequestDetailScreen(changeRequestId: id);
        },
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      GoRoute(
        path: '/issues/mine',
        builder: (context, state) => const MyIssuesScreen(),
      ),
      GoRoute(
        path: '/recommendations',
        builder: (context, state) => const RecommendationScreen(),
      ),
      GoRoute(
        path: '/battery-swap',
        builder: (context, state) {
          final stationId = state.uri.queryParameters['stationId'];
          return BatterySwapScreen(preSelectedStationId: stationId);
        },
      ),
      GoRoute(
        path: '/battery-swap/reservations',
        builder: (context, state) {
          final reservationId = state.uri.queryParameters['reservationId'];
          return BatterySwapReservationScreen(reservationId: reservationId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Loyalty routes
      GoRoute(
        path: '/loyalty',
        builder: (context, state) => const LoyaltyHomeScreen(),
      ),
      GoRoute(
        path: '/loyalty/points',
        builder: (context, state) => const PointHistoryScreen(),
      ),
      GoRoute(
        path: '/loyalty/badges',
        builder: (context, state) => const BadgeCollectionScreen(),
      ),
      GoRoute(
        path: '/loyalty/referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/loyalty/rate/:stationId',
        builder: (context, state) {
          final stationId = state.pathParameters['stationId'] ?? '';
          final extra = state.extra as Map<String, dynamic>?;
          return RateStationScreen(
            stationId: stationId,
            eligibilityId: extra?['eligibilityId'],
          );
        },
      ),
      // Voucher routes
      GoRoute(
        path: '/loyalty/vouchers/catalog',
        builder: (context, state) => const VoucherCatalogScreen(),
      ),
      GoRoute(
        path: '/loyalty/vouchers/mine',
        builder: (context, state) => const MyVouchersScreen(),
      ),
      GoRoute(
        path: '/loyalty/vouchers/redemptions/:id',
        builder: (context, state) => VoucherDetailScreen(
          redemptionId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

