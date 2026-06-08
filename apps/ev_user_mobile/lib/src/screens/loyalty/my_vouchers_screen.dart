import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../providers/loyalty_providers.dart';
import 'package:shared_api/shared_api.dart';

/// My Vouchers Screen - Shows user's redeemed vouchers in tabs
class MyVouchersScreen extends ConsumerStatefulWidget {
  const MyVouchersScreen({super.key});

  @override
  ConsumerState<MyVouchersScreen> createState() => _MyVouchersScreenState();
}

class _MyVouchersScreenState extends ConsumerState<MyVouchersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vouchers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Available'),
            Tab(text: 'Used'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VoucherListTab(status: 'REDEEMED'),
          _VoucherListTab(status: 'USED'),
          _VoucherListTab(status: 'EXPIRED'),
        ],
      ),
    );
  }
}

class _VoucherListTab extends ConsumerWidget {
  final String status;
  const _VoucherListTab({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(myVouchersProvider(status));

    return vouchersAsync.when(
      loading: () => const LoadingState(message: 'Loading vouchers...'),
      error: (e, _) => ErrorState(
        message: formatApiError(e),
        onRetry: () => ref.invalidate(myVouchersProvider(status)),
      ),
      data: (vouchers) {
        if (vouchers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.ticket,
                    size: 64,
                    color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  status == 'REDEEMED'
                      ? 'No vouchers yet'
                      : status == 'USED'
                          ? 'No used vouchers'
                          : 'No expired vouchers',
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),
                if (status == 'REDEEMED') ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/loyalty/vouchers/catalog'),
                    icon: const FaIcon(FontAwesomeIcons.gift),
                    label: const Text('Redeem Voucher'),
                  ),
                ],
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vouchers.length,
          itemBuilder: (context, index) {
            final voucher = vouchers[index];
            return _MyVoucherCard(voucher: voucher);
          },
        );
      },
    );
  }
}

class _MyVoucherCard extends StatelessWidget {
  final VoucherRedemption voucher;
  const _MyVoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final def = voucher.definition;
    final isExpired = voucher.isExpired && voucher.status == 'REDEEMED';
    final statusColor = voucher.status == 'REDEEMED'
        ? (isExpired ? Colors.red : Colors.green)
        : voucher.status == 'USED'
            ? Colors.blue
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/loyalty/vouchers/redemptions/${voucher.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      def?.name ?? 'Voucher',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isExpired ? 'Expired' : voucher.statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.barcode, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Code: ${voucher.voucherCode}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.clock, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    voucher.usedAt != null
                        ? 'Used: ${_formatDate(voucher.usedAt!)}'
                        : 'Expires: ${_formatDate(voucher.expiresAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.star, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${voucher.pointsSpent} pts',
                    style: TextStyle(color: Colors.red[400], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
