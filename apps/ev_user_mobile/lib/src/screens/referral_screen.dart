import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/loyalty_providers.dart';

/// Referral Screen - Share referral code
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(referralCodeProvider.notifier).loadCode();
    });
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    AppToast.showSuccess(context, 'Referral code copied!');
  }

  void _shareReferral(String code, String link) {
    final text = 'Join VoltGo and earn rewards! Use my referral code: $code\n$link';
    Clipboard.setData(ClipboardData(text: text));
    AppToast.showSuccess(context, 'Share text copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(referralCodeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refer a Friend'),
      ),
      body: state.isLoading
          ? const LoadingState(message: 'Loading...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header illustration
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.gift,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Share VoltGo',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Invite friends to join VoltGo and earn rewards together',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Referral code card
                  if (state.code != null) ...[
                    _ReferralCodeCard(
                      code: state.code!.code,
                      onCopy: () => _copyCode(state.code!.code),
                    ),
                    const SizedBox(height: 16),
                    _ReferralLinkCard(
                      link: state.code!.referralLink,
                      onShare: () => _shareReferral(
                        state.code!.code,
                        state.code!.referralLink,
                      ),
                    ),
                  ] else if (state.error != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.triangleExclamation,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load referral code',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatApiError(state.error!),
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(referralCodeProvider.notifier).refresh(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  // How it works
                  _HowItWorksSection(),
                  const SizedBox(height: 32),
                  // Rewards breakdown
                  _RewardsBreakdown(),
                ],
              ),
            ),
    );
  }
}

/// Referral code display card
class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _ReferralCodeCard({
    required this.code,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Your Referral Code',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Text(
                code,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const FaIcon(FontAwesomeIcons.copy, size: 16),
                label: const Text('Copy Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Referral link card
class _ReferralLinkCard extends StatelessWidget {
  final String link;
  final VoidCallback onShare;

  const _ReferralLinkCard({
    required this.link,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.link,
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
                        'Share Link',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        link,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShare,
                icon: const FaIcon(FontAwesomeIcons.share, size: 16),
                label: const Text('Share Invite'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How it works section
class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How It Works',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _StepItem(
          number: '1',
          title: 'Share Your Code',
          description: 'Share your referral code or link with friends',
          icon: FontAwesomeIcons.shareNodes,
        ),
        const SizedBox(height: 12),
        _StepItem(
          number: '2',
          title: 'Friend Signs Up',
          description: 'Your friend creates an account using your code',
          icon: FontAwesomeIcons.userPlus,
        ),
        const SizedBox(height: 12),
        _StepItem(
          number: '3',
          title: 'Friend Completes Booking',
          description: 'When they complete their first charging session',
          icon: FontAwesomeIcons.bolt,
        ),
        const SizedBox(height: 12),
        _StepItem(
          number: '4',
          title: 'Both Earn Rewards',
          description: 'You and your friend each get 50 bonus points',
          icon: FontAwesomeIcons.gift,
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rewards breakdown
class _RewardsBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.sackDollar,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reward Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RewardItem(
                    label: 'You Earn',
                    points: '50',
                    icon: FontAwesomeIcons.user,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                Expanded(
                  child: _RewardItem(
                    label: 'Friend Earns',
                    points: '50',
                    icon: FontAwesomeIcons.userPlus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.checkCircle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Both parties receive points when friend completes first booking',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
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

class _RewardItem extends StatelessWidget {
  final String label;
  final String points;
  final IconData icon;

  const _RewardItem({
    required this.label,
    required this.points,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        FaIcon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          '+$points',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          'points',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
