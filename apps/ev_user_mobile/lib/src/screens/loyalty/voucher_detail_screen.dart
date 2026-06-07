import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../providers/loyalty_providers.dart';
import 'package:shared_api/shared_api.dart';

/// Voucher Detail Screen - Shows redemption detail with apply action
class VoucherDetailScreen extends ConsumerWidget {
  final String redemptionId;

  const VoucherDetailScreen({super.key, required this.redemptionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redemptionAsync = ref.watch(voucherRedemptionDetailProvider(redemptionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher Detail'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: redemptionAsync.when(
        loading: () => const LoadingState(message: 'Loading...'),
        error: (e, _) => ErrorState(
          message: formatApiError(e),
          onRetry: () => ref.invalidate(voucherRedemptionDetailProvider(redemptionId)),
        ),
        data: (voucher) => _VoucherDetailContent(voucher: voucher),
      ),
    );
  }
}

class _VoucherDetailContent extends ConsumerWidget {
  final VoucherRedemption voucher;
  const _VoucherDetailContent({required this.voucher});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = voucher.definition;
    final isExpired = voucher.isExpired && voucher.status == 'REDEEMED';
    final canUse = voucher.status == 'REDEEMED' && !isExpired;
    final applyState = ref.watch(applyVoucherProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Voucher card
        Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIcon(def?.iconLabel ?? ''),
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      def?.name ?? 'Voucher',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                def?.description ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  def?.typeLabel ?? voucher.status,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Status chip
        Chip(
          label: Text('Expired'),
          backgroundColor: voucher.status == 'REDEEMED'
              ? (isExpired ? Colors.red[50] : Colors.green[50])
              : voucher.status == 'USED'
                  ? Colors.blue[50]
                  : Colors.grey[200],
        ),
        const SizedBox(height: 16),

        // Info section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'Voucher Code',
                  value: voucher.voucherCode,
                  copyable: true,
                ),
                const Divider(),
                _InfoRow(
                  label: 'Redeemed',
                  value: _formatDate(voucher.redeemedAt),
                ),
                const Divider(),
                _InfoRow(
                  label: 'Expired',
                  value: _formatDate(voucher.expiresAt),
                ),
                if (voucher.usedAt != null) ...[
                  const Divider(),
                  _InfoRow(
                    label: 'Used',
                    value: _formatDate(voucher.usedAt!),
                  ),
                ],
                const Divider(),
                _InfoRow(
                  label: 'Points Redeemed',
                  value: '${voucher.pointsSpent} pts',
                  valueColor: Colors.red,
                ),
              ],
            ),
          ),
        ),

        if (canUse) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: applyState.isLoading
                ? null
                : () => _showApplyDialog(context, ref),
            icon: applyState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const FaIcon(FontAwesomeIcons.gift),
            label: Text(applyState.isLoading ? 'Processing...' : 'Apply to Booking'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],

        if (isExpired) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This voucher has expired and cannot be used.',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (voucher.status == 'USED') ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Voucher applied to ${voucher.serviceType ?? "booking"} successfully.',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showApplyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final def = voucher.definition;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Voucher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter booking or reservation ID:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Booking ID or Reservation ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(ctx);

              try {
                VoucherRedemption? result;
                if (def?.voucherType == 'FREE_SERVICE' && def?.serviceType == 'BATTERY_SWAP') {
                  result = await ref.read(applyVoucherProvider.notifier).applyToSwap(voucher.id, id);
                } else {
                  result = await ref.read(applyVoucherProvider.notifier).applyToBooking(voucher.id, id);
                }
                if (result == null) return;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voucher applied successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Apply'),
          ),
        ],
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

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
              ),
              if (copyable) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.copy, size: 16, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
