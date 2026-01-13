import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_api/shared_api.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/main_scaffold.dart';

/// Location update state provider
final locationUpdateProvider = StateNotifierProvider<LocationUpdateNotifier, LocationUpdateState>((ref) {
  return LocationUpdateNotifier(ref);
});

class LocationUpdateState {
  final bool isLoading;
  final String? error;
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;

  LocationUpdateState({
    this.isLoading = false,
    this.error,
    this.lat,
    this.lng,
    this.updatedAt,
  });

  LocationUpdateState copyWith({
    bool? isLoading,
    String? error,
    double? lat,
    double? lng,
    DateTime? updatedAt,
  }) {
    return LocationUpdateState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LocationUpdateNotifier extends StateNotifier<LocationUpdateState> {
  final Ref ref;

  LocationUpdateNotifier(this.ref) : super(LocationUpdateState());

  Future<void> updateLocationFromGPS() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            error: 'Location permission denied. Please enable location access in settings.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          error: 'Location permission permanently denied. Please enable in app settings.',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      // Update location via API
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        state = state.copyWith(isLoading: false, error: 'API client not initialized');
        return;
      }

      final response = await factory.collabMobile.updateLocation(
        lat: position.latitude,
        lng: position.longitude,
        sourceNote: 'GPS accuracy: ${position.accuracy.toStringAsFixed(1)}m',
      );

      state = state.copyWith(
        isLoading: false,
        lat: (response['lat'] as num?)?.toDouble(),
        lng: (response['lng'] as num?)?.toDouble(),
        updatedAt: response['updatedAt'] != null 
            ? DateTime.parse(response['updatedAt'] as String)
            : DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update location: ${e.toString()}',
      );
    }
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final locationState = ref.watch(locationUpdateProvider);
    final theme = Theme.of(context);
    
    return CollabMainScaffold(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        (authState.email ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      authState.email ?? 'User',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusPill(
                      label: authState.role ?? 'Unknown',
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Update Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Current Location',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Location display
                    if (locationState.lat != null && locationState.lng != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Location Updated',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${locationState.lat!.toStringAsFixed(6)}, Lng: ${locationState.lng!.toStringAsFixed(6)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (locationState.updatedAt != null)
                              Text(
                                'Updated: ${_formatDateTime(locationState.updatedAt!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error display
                    if (locationState.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationState.error!,
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: locationState.isLoading
                            ? null
                            : () => ref.read(locationUpdateProvider.notifier).updateLocationFromGPS(),
                        icon: locationState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.gps_fixed),
                        label: Text(locationState.isLoading ? 'Getting Location...' : 'Update Location from GPS'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your location is used to assign verification tasks near you.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Profile button
            ElevatedButton.icon(
              onPressed: () => context.push('/profile/edit'),
              icon: const FaIcon(FontAwesomeIcons.pen, size: 16),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Logout button
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(authStateNotifierProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

