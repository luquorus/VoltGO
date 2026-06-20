import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../providers/loyalty_providers.dart';

/// Reusable Ratings & Reviews section for any station detail surface
/// (charging station, battery swap station).
///
/// Watches:
/// - [stationRatingSummaryProvider] for aggregate (avg / total / breakdown)
/// - [eligibleStationsForRatingProvider] to decide Rate vs View-all button
///
/// Tapping the button navigates to `/loyalty/rate/:stationId`, passing the
/// matching `eligibilityId` (if any) so the rate screen can submit a verified
/// rating tied to the user's prior BOOKING_USAGE / SWAP_USAGE / CR.
class StationRatingSection extends ConsumerWidget {
  final String stationId;

  /// When true the title is rendered in a slightly smaller style and the
  /// outer horizontal padding defaults to 0 (useful inside cards/sheets that
  /// already provide their own padding).
  final bool compact;

  /// Horizontal padding applied to the outer column. Ignored when null and
  /// replaced with a default based on [compact].
  final double? horizontalPadding;

  const StationRatingSection({
    super.key,
    required this.stationId,
    this.compact = false,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(stationRatingSummaryProvider(stationId));
    final eligibleAsync = ref.watch(eligibleStationsForRatingProvider);

    final hPad = horizontalPadding ?? (compact ? 0.0 : 24.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ratings & Reviews',
            style: (compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge)
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (summary) => Card(
              margin: compact ? EdgeInsets.zero : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              summary.averageRating.toStringAsFixed(1),
                              style:
                                  theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (index) {
                                final rating = index + 1;
                                if (summary.averageRating >= rating) {
                                  return const Icon(Icons.star,
                                      size: 16, color: Colors.amber);
                                } else if (summary.averageRating >=
                                    rating - 0.5) {
                                  return const Icon(Icons.star_half,
                                      size: 16, color: Colors.amber);
                                } else {
                                  return const Icon(Icons.star_border,
                                      size: 16, color: Colors.amber);
                                }
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${summary.totalRatings} reviews',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            children: List.generate(5, (index) {
                              final star = 5 - index;
                              final percent =
                                  summary.getPercentForRating(star);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Text('$star',
                                        style: theme.textTheme.bodySmall),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.star,
                                        size: 12, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: percent / 100,
                                          minHeight: 8,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  Colors.amber),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        '${summary.getCountForRating(star)}',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          eligibleAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (eligible) {
              final matching = eligible
                  .where((s) =>
                      s.stationId == stationId && s.isRated == false)
                  .firstOrNull;
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push(
                      '/loyalty/rate/$stationId',
                      extra: {'eligibilityId': matching?.eligibilityId},
                    );
                  },
                  icon: const FaIcon(FontAwesomeIcons.star),
                  label: Text(matching != null
                      ? 'Rate this station'
                      : 'View all ratings'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}