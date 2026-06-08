import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/loyalty_providers.dart';
import 'package:shared_api/shared_api.dart';

/// Rate Station Screen
class RateStationScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String? eligibilityId;

  const RateStationScreen({
    super.key,
    required this.stationId,
    this.eligibilityId,
  });

  @override
  ConsumerState<RateStationScreen> createState() => _RateStationScreenState();
}

class _RateStationScreenState extends ConsumerState<RateStationScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  int get _estimatedPoints {
    int points = 10;
    if (_commentController.text.trim().length >= 30) points += 5;
    return points;
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      AppToast.showError(context, 'Please select a star rating');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = SubmitRatingRequest(
        stationId: widget.stationId,
        eligibilityId: widget.eligibilityId,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      await ref.read(submitRatingProvider.notifier).submit(request);

      if (mounted) {
        AppToast.showSuccess(context, 'Thank you! You earned +$_estimatedPoints points');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, formatApiError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Station'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'How was your experience?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a star to rate',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isSelected = starIndex <= _rating;

                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              size: 48,
                              color: isSelected ? Colors.amber : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Rating label
                  Text(
                    _getRatingLabel(_rating),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _getRatingColor(_rating),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Comment field
                  Text(
                    'Share your experience (optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Min. 30 characters for +5 bonus points',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Describe your experience at this station...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  // Points preview
                  _PointsPreview(
                    basePoints: 10,
                    hasComment: _commentController.text.trim().length >= 30,
                  ),
                ],
              ),
            ),
          ),
          // Submit button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating > 0 && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Rating'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return 'Tap to rate';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.lightGreen;
      case 5: return Colors.green;
      default: return Colors.grey;
    }
  }
}

/// Points preview widget
class _PointsPreview extends StatelessWidget {
  final int basePoints;
  final bool hasComment;

  const _PointsPreview({
    required this.basePoints,
    required this.hasComment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPoints = basePoints + (hasComment ? 5 : 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(
              FontAwesomeIcons.sackDollar,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '+$totalPoints',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      ' pts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (hasComment) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '+5 bonus',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
