import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/admin_scaffold.dart';

/// Rating Moderation Screen - View and moderate user ratings with real data
class RatingModerationScreen extends ConsumerStatefulWidget {
  const RatingModerationScreen({super.key});

  @override
  ConsumerState<RatingModerationScreen> createState() => _RatingModerationScreenState();
}

class _RatingModerationScreenState extends ConsumerState<RatingModerationScreen> {
  String? _statusFilter;
  final _stationController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _stationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(adminRatingsProvider.notifier).loadMore();
    }
  }

  void _applyFilters() {
    ref.read(adminRatingsProvider.notifier).setFilters(
      status: _statusFilter,
      station: _stationController.text.isEmpty ? null : _stationController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratingsState = ref.watch(adminRatingsProvider);

    return AdminScaffold(
      title: 'Rating Moderation',
      body: Padding(
        padding: responsivePadding(context),
        child: Column(
          children: [
            // Filters
            Container(
              padding: responsivePaddingScaled(context, 0.67),
              decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: AdminTheme.outlineLight),
              ),
            ),
            child: Row(
              children: [
                // Status filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _statusFilter,
                    hint: const Text('All'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'HIDDEN', child: Text('Hidden')),
                      DropdownMenuItem(value: 'FLAGGED', child: Text('Flagged')),
                    ],
                    onChanged: (value) {
                      setState(() => _statusFilter = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Station filter
                Expanded(
                  child: TextField(
                    controller: _stationController,
                    decoration: const InputDecoration(
                      labelText: 'Station',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _stationController.clear();
                    setState(() => _statusFilter = null);
                    ref.read(adminRatingsProvider.notifier).refresh();
                  },
                  tooltip: 'Reset & Refresh',
                ),
                const SizedBox(width: 8),
                if (ratingsState.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${ratingsState.ratings.length}${ratingsState.hasMore ? '+' : ''} ratings',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryTeal.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Station', style: TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text('User ID', style: TextStyle(fontWeight: FontWeight.w600))),
                            SizedBox(width: 80, child: Text('Rating', style: TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 3, child: Text('Comment', style: TextStyle(fontWeight: FontWeight.w600))),
                            SizedBox(width: 80, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                            SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                            SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Loading/Error/Empty state
                      if (ratingsState.isLoading && ratingsState.ratings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        )
                      else if (ratingsState.error != null && ratingsState.ratings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
                              const SizedBox(height: 8),
                              Text('Lỗi: ${ratingsState.error}'),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => ref.read(adminRatingsProvider.notifier).refresh(),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      else if (ratingsState.ratings.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                _statusFilter != null
                                    ? 'Không có rating với trạng thái $_statusFilter'
                                    : 'Chưa có rating nào',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      else
                        ...ratingsState.ratings.map((rating) => _RatingRow(
                          rating: rating,
                          onHide: () => _hideRating(rating.id),
                          onViewDetails: () => _showRatingDetails(rating),
                        )),
                      if (ratingsState.hasMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _hideRating(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hide Rating'),
        content: const Text('Bạn có chắc muốn ẩn rating này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ẩn'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(adminRatingsProvider.notifier).hideRating(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating đã được ẩn')),
        );
      }
    }
  }

  void _showRatingDetails(AdminStationRating rating) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rating Details - ${rating.stationName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Station', value: rating.stationName),
            _DetailRow(label: 'Rating ID', value: rating.id),
            _DetailRow(label: 'Rating', value: '${rating.rating}/5 stars'),
            _DetailRow(label: 'Verified', value: rating.isVerified ? 'Yes' : 'No'),
            _DetailRow(label: 'Helpful Count', value: '${rating.helpfulCount}'),
            _DetailRow(label: 'Status', value: rating.isVerified ? 'ACTIVE' : 'PENDING'),
            _DetailRow(label: 'Date', value: _formatDate(rating.createdAt)),
            const SizedBox(height: 16),
            const Text('Comment:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(rating.comment ?? 'No comment provided.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final AdminStationRating rating;
  final VoidCallback onHide;
  final VoidCallback onViewDetails;

  const _RatingRow({
    required this.rating,
    required this.onHide,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = rating.isVerified;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminTheme.outlineLight.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(rating.stationName, overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2,
            child: Text(
              rating.id.length > 8 ? '${rating.id.substring(0, 8)}...' : rating.id,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < rating.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber,
                );
              }),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rating.comment ?? '-',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(
            width: 80,
            child: _StatusBadge(isVerified: isActive),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _formatDate(rating.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('View'),
                ),
                if (isActive)
                  TextButton(
                    onPressed: onHide,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Hide'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isVerified;

  const _StatusBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    final status = isVerified ? 'ACTIVE' : 'PENDING';
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'HIDDEN':
        color = Colors.grey;
        break;
      case 'FLAGGED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
