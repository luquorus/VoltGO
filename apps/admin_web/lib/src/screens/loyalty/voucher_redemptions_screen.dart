import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';
import '../../utils/responsive_utils.dart';

/// Admin redemptions screen providers
final adminRedemptionsProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, status) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return factory.admin.getVoucherRedemptions(status: status);
});

/// Redemptions tab in voucher management
class VoucherRedemptionsScreen extends ConsumerStatefulWidget {
  const VoucherRedemptionsScreen({super.key});

  @override
  ConsumerState<VoucherRedemptionsScreen> createState() => _VoucherRedemptionsScreenState();
}

class _VoucherRedemptionsScreenState extends ConsumerState<VoucherRedemptionsScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final redemptionsAsync = ref.watch(adminRedemptionsProvider(_statusFilter));
    final mobile = isMobile(context);

    return AdminScaffold(
      title: 'Danh sách Redemption',
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: EdgeInsets.all(responsiveHPadding(context)),
            child: mobile
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(label: const Text('Tất cả'), selected: _statusFilter == null, onSelected: (_) => setState(() => _statusFilter = null)),
                      FilterChip(label: const Text('Chưa dùng'), selected: _statusFilter == 'REDEEMED', onSelected: (_) => setState(() { _statusFilter = 'REDEEMED'; })),
                      FilterChip(label: const Text('Đã dùng'), selected: _statusFilter == 'USED', onSelected: (_) => setState(() { _statusFilter = 'USED'; })),
                      FilterChip(label: const Text('Hết hạn'), selected: _statusFilter == 'EXPIRED', onSelected: (_) => setState(() { _statusFilter = 'EXPIRED'; })),
                    ],
                  )
                : Row(
                    children: [
                      FilterChip(label: const Text('Tất cả'), selected: _statusFilter == null, onSelected: (_) => setState(() => _statusFilter = null)),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Chưa dùng'), selected: _statusFilter == 'REDEEMED', onSelected: (_) => setState(() { _statusFilter = 'REDEEMED'; })),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Đã dùng'), selected: _statusFilter == 'USED', onSelected: (_) => setState(() { _statusFilter = 'USED'; })),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('Hết hạn'), selected: _statusFilter == 'EXPIRED', onSelected: (_) => setState(() { _statusFilter = 'EXPIRED'; })),
                    ],
                  ),
          ),
          Expanded(
            child: redemptionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (data) {
                final content = data['content'] as List<dynamic>? ?? [];
                final totalElements = data['totalElements'] as int? ?? 0;

                if (content.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('Chưa có redemption nào'),
                        const SizedBox(height: 8),
                        Text(
                          '$totalElements total',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.all(responsiveHPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalElements redemptions',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Mã Code')),
                              DataColumn(label: Text('User ID')),
                              DataColumn(label: Text('Voucher')),
                              DataColumn(label: Text('Điểm')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Redeemed')),
                              DataColumn(label: Text('Hết hạn')),
                              DataColumn(label: Text('Used At')),
                            ],
                            rows: content.map((r) {
                              final def = r['definition'] as Map<String, dynamic>?;
                              final metadata = r['metadata'] as Map<String, dynamic>?;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      r['voucherCode'] as String? ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      (r['userId'] as String? ?? '').substring(0, 8) + '...',
                                    ),
                                  ),
                                  DataCell(Text(def?['name'] as String? ?? 'Unknown')),
                                  DataCell(Text('${r['pointsSpent'] ?? 0}')),
                                  DataCell(_StatusChip(status: r['status'] as String? ?? '')),
                                  DataCell(Text(_formatDate(r['redeemedAt'] as String?))),
                                  DataCell(Text(_formatDate(r['expiresAt'] as String?))),
                                  DataCell(Text(_formatDate(r['usedAt'] as String?))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'REDEEMED':
        color = Colors.blue;
        break;
      case 'USED':
        color = Colors.green;
        break;
      case 'EXPIRED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
