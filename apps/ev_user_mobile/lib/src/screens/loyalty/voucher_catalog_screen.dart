import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../providers/loyalty_providers.dart';
import 'package:shared_api/shared_api.dart';

/// Voucher Catalog Screen - Shows available vouchers to redeem
class VoucherCatalogScreen extends ConsumerWidget {
  const VoucherCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(availableVouchersProvider);
    final profileAsync = ref.watch(loyaltyProfileProvider);
    final redeemState = ref.watch(redeemVoucherProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redeem Voucher'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: vouchersAsync.when(
        loading: () => const LoadingState(message: 'Loading vouchers...'),
        error: (e, _) => ErrorState(
          message: formatApiError(e),
          onRetry: () => ref.invalidate(availableVouchersProvider),
        ),
        data: (vouchers) {
          final currentPoints = profileAsync.whenOrNull(data: (p) => p.currentPoints) ?? 0;
          if (vouchers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.ticketSimple,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No vouchers available',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Points balance card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const FaIcon(FontAwesomeIcons.star, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Points Balance',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                        Text(
                          '$currentPoints pts',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Available Vouchers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...vouchers.map((v) => _VoucherCard(
                voucher: v,
                currentPoints: currentPoints,
                redeemState: redeemState,
                onRedeem: () => _redeemVoucher(context, ref, v),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _redeemVoucher(BuildContext context, WidgetRef ref, VoucherDefinition voucher) async {
    final profile = ref.read(loyaltyProfileProvider).valueOrNull;
    final currentPoints = profile?.currentPoints ?? 0;

    if (currentPoints < voucher.pointCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need ${voucher.pointCost} pts. You have $currentPoints pts.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Redemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''Redeem "${voucher.name}"?'''),
            const SizedBox(height: 8),
            Text(
              '${voucher.pointCost} pts',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 4),
            Text('Voucher valid for ${voucher.validityDays} days'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(redeemVoucherProvider.notifier).redeem(voucher.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redeemed "${voucher.name}" successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _VoucherCard extends StatelessWidget {
  final VoucherDefinition voucher;
  final int currentPoints;
  final RedeemVoucherState redeemState;
  final VoidCallback onRedeem;

  const _VoucherCard({
    required this.voucher,
    required this.currentPoints,
    required this.redeemState,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = currentPoints >= voucher.pointCost;
    final isRedeeming = redeemState.isLoading;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: (voucher.status == 'ACTIVE' && canAfford && !isRedeeming) ? onRedeem : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: voucher.status == 'ACTIVE' && canAfford
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(voucher.iconLabel),
                  color: voucher.status == 'ACTIVE' && canAfford
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voucher.description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valid for ${voucher.validityDays} days',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: voucher.status == 'ACTIVE' && canAfford
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: isRedeeming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '${voucher.pointCost} pts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  if (!canAfford && voucher.status == 'ACTIVE')
                    Text(
                      'Need ${voucher.pointCost - currentPoints} more pts',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  if (voucher.status != 'ACTIVE')
                    Text(
                      'Unavailable',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String label) {
    switch (label) {
      case 'discount': return Icons.discount;
      case 'ev_station': return Icons.ev_station;
      case 'battery_charging_full': return Icons.battery_charging_full;
      default: return Icons.card_giftcard;
    }
  }
}
