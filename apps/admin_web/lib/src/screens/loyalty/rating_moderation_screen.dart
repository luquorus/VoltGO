import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';

/// Rating Moderation Screen - View and moderate user ratings
class RatingModerationScreen extends ConsumerStatefulWidget {
  const RatingModerationScreen({super.key});

  @override
  ConsumerState<RatingModerationScreen> createState() => _RatingModerationScreenState();
}

class _RatingModerationScreenState extends ConsumerState<RatingModerationScreen> {
  String? _statusFilter;
  String? _stationFilter;
  String? _userFilter;

  final List<_RatingItem> _ratings = [
    _RatingItem(
      id: '1',
      stationName: 'EV Station Downtown',
      userEmail: 'user1@example.com',
      rating: 5,
      comment: 'Excellent service and very clean facilities. Highly recommended!',
      status: 'ACTIVE',
      helpfulCount: 12,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _RatingItem(
      id: '2',
      stationName: 'Fast Charge Center',
      userEmail: 'user2@example.com',
      rating: 4,
      comment: 'Good charging speed, but a bit crowded on weekends.',
      status: 'ACTIVE',
      helpfulCount: 5,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _RatingItem(
      id: '3',
      stationName: 'Green Energy Hub',
      userEmail: 'user3@example.com',
      rating: 2,
      comment: 'Chargers were not working properly. Had to wait 30 mins.',
      status: 'ACTIVE',
      helpfulCount: 3,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _RatingItem(
      id: '4',
      stationName: 'City Power Station',
      userEmail: 'user4@example.com',
      rating: 1,
      comment: 'Worst experience ever. Broken chargers and rude staff.',
      status: 'FLAGGED',
      helpfulCount: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _RatingItem(
      id: '5',
      stationName: 'Express Charging',
      userEmail: 'user5@example.com',
      rating: 3,
      comment: 'Average experience. Could be better.',
      status: 'HIDDEN',
      helpfulCount: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Rating Moderation',
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
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
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'HIDDEN', child: Text('Hidden')),
                      DropdownMenuItem(value: 'FLAGGED', child: Text('Flagged')),
                    ],
                    onChanged: (value) {
                      setState(() => _statusFilter = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Station filter
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Station',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => _stationFilter = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // User filter
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'User',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => _userFilter = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: SingleChildScrollView(
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
                        child: Row(
                          children: [
                            const Expanded(flex: 2, child: Text('Station', style: TextStyle(fontWeight: FontWeight.w600))),
                            const Expanded(flex: 2, child: Text('User', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(width: 80, child: Text('Rating', style: TextStyle(fontWeight: FontWeight.w600))),
                            const Expanded(flex: 3, child: Text('Comment', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(width: 80, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Rows
                      ..._filteredRatings().map((rating) => _RatingRow(
                        rating: rating,
                        onHide: () => _hideRating(rating.id),
                        onViewDetails: () => _showRatingDetails(rating),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_RatingItem> _filteredRatings() {
    return _ratings.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_stationFilter != null && _stationFilter!.isNotEmpty &&
          !r.stationName.toLowerCase().contains(_stationFilter!.toLowerCase())) return false;
      if (_userFilter != null && _userFilter!.isNotEmpty &&
          !r.userEmail.toLowerCase().contains(_userFilter!.toLowerCase())) return false;
      return true;
    }).toList();
  }

  void _hideRating(String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rating $id hidden')),
    );
  }

  void _showRatingDetails(_RatingItem rating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rating Details - ${rating.stationName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Station', value: rating.stationName),
            _DetailRow(label: 'User', value: rating.userEmail),
            _DetailRow(label: 'Rating', value: '${rating.rating}/5 stars'),
            _DetailRow(label: 'Status', value: rating.status),
            _DetailRow(label: 'Helpful Count', value: '${rating.helpfulCount}'),
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
            onPressed: () => Navigator.pop(context),
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

class _RatingItem {
  final String id;
  final String stationName;
  final String userEmail;
  final int rating;
  final String? comment;
  final String status;
  final int helpfulCount;
  final DateTime createdAt;

  _RatingItem({
    required this.id,
    required this.stationName,
    required this.userEmail,
    required this.rating,
    this.comment,
    required this.status,
    required this.helpfulCount,
    required this.createdAt,
  });
}

class _RatingRow extends StatelessWidget {
  final _RatingItem rating;
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminTheme.outlineLight.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(rating.stationName)),
          Expanded(flex: 2, child: Text(_maskEmail(rating.userEmail))),
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
            child: _StatusBadge(status: rating.status),
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
                if (rating.status == 'ACTIVE')
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

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    if (name.length <= 2) return '${name[0]}***@${parts[1]}';
    return '${name.substring(0, 2)}***@${parts[1]}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
