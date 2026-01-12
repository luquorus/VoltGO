import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/station_providers.dart';
import '../widgets/report_issue_bottom_sheet.dart';

/// Station Detail Screen
class StationDetailScreen extends ConsumerStatefulWidget {
  final String stationId;

  const StationDetailScreen({
    super.key,
    required this.stationId,
  });

  @override
  ConsumerState<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends ConsumerState<StationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Load station detail on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stationDetailProvider.notifier).loadStation(widget.stationId);
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(stationDetailProvider.notifier).refresh(widget.stationId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationDetailProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Station Details',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () => context.pop(),
          tooltip: 'Close',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildContent(context, state, theme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    StationDetailState state,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: LoadingState());
    }

    if (state.error != null) {
      return Center(
        child: ErrorState(
          message: state.error!.message,
          onRetry: () => _onRefresh(),
        ),
      );
    }

    if (state.station == null) {
      return const Center(child: EmptyState(message: 'Station not found'));
    }

    final station = state.station!;
    final name = station['name'] as String? ?? 'Unknown Station';
    final address = station['address'] as String? ?? '';
    final trustScore = station['trustScore'] as int? ?? 0;
    final operatingHours = station['operatingHours'] as String? ?? 'N/A';
    final parking = station['parking'] as String? ?? 'UNKNOWN';
    final visibility = station['visibility'] as String? ?? 'PUBLIC';
    final publicStatus = station['publicStatus'] as String? ?? 'ACTIVE';
    final ports = station['ports'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: name + address + trustScore badge
          _buildHeader(context, theme, name, address, trustScore),

          // Info section: hours, parking, status
          _buildInfoSection(context, theme, operatingHours, parking, publicStatus, visibility),

          // Charging ports list (DC/AC grouped)
          _buildPortsSection(context, theme, ports),

          const SizedBox(height: 24),

          // CTA: Book a slot
          _buildBookButton(context, theme, widget.stationId, name),

          const SizedBox(height: 12),

          // CTA: Report issue
          _buildReportIssueButton(context, theme, widget.stationId, name),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    String name,
    String address,
    int trustScore,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      address,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ScoreBadge(score: trustScore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context,
    ThemeData theme,
    String operatingHours,
    String parking,
    String publicStatus,
    String visibility,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Information',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            context,
            theme,
            FontAwesomeIcons.clock,
            'Operating Hours',
            operatingHours,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            theme,
            FontAwesomeIcons.parking,
            'Parking',
            _formatParking(parking),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            theme,
            FontAwesomeIcons.circleCheck,
            'Status',
            _formatStatus(publicStatus),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            context,
            theme,
            FontAwesomeIcons.eye,
            'Visibility',
            _formatVisibility(visibility),
          ),
        ],
      ),
    );
  }

  Widget _buildPortsSection(
    BuildContext context,
    ThemeData theme,
    List<dynamic> ports,
  ) {
    // Group ports by powerType
    final dcPorts = ports.where((p) => (p as Map)['powerType'] == 'DC').toList();
    final acPorts = ports.where((p) => (p as Map)['powerType'] == 'AC').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charging Ports',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (dcPorts.isNotEmpty) ...[
            _buildPortGroup(context, theme, 'DC Ports', dcPorts, Colors.blue),
            const SizedBox(height: 16),
          ],
          if (acPorts.isNotEmpty) ...[
            _buildPortGroup(context, theme, 'AC Ports', acPorts, Colors.green),
          ],
          if (ports.isEmpty)
            Text(
              'No charging ports available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPortGroup(
    BuildContext context,
    ThemeData theme,
    String title,
    List<dynamic> ports,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...ports.map((port) {
          final powerKw = (port as Map)['powerKw'] as double?;
          final count = (port)['count'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    FaIcon(FontAwesomeIcons.bolt, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (powerKw != null)
                            Text(
                              '${powerKw.toStringAsFixed(1)} kW',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'Standard',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            '$count port${count != 1 ? 's' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBookButton(BuildContext context, ThemeData theme, String stationId, String stationName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: PrimaryButton(
        label: 'Book a Slot',
        onPressed: () {
          context.push('/bookings/create?stationId=$stationId&stationName=${Uri.encodeComponent(stationName)}');
        },
      ),
    );
  }

  Widget _buildReportIssueButton(BuildContext context, ThemeData theme, String stationId, String stationName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SecondaryButton(
        label: 'Report Issue',
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ReportIssueBottomSheet(
              stationId: stationId,
              stationName: stationName,
            ),
          );
        },
      ),
    );
  }

  String _formatParking(String parking) {
    switch (parking) {
      case 'PAID':
        return 'Paid Parking';
      case 'FREE':
        return 'Free Parking';
      case 'UNKNOWN':
        return 'Unknown';
      default:
        return parking;
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Active';
      case 'INACTIVE':
        return 'Inactive';
      case 'MAINTENANCE':
        return 'Under Maintenance';
      default:
        return status;
    }
  }

  String _formatVisibility(String visibility) {
    switch (visibility) {
      case 'PUBLIC':
        return 'Public';
      case 'PRIVATE':
        return 'Private';
      case 'RESTRICTED':
        return 'Restricted';
      default:
        return visibility;
    }
  }

  Widget _buildInfoCard(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FaIcon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

