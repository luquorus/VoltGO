import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';
import '../../utils/responsive_utils.dart';

/// Admin voucher management providers
final adminVouchersProvider = FutureProvider<List<VoucherDefinition>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.admin.getVouchers();
  return data.map((e) => VoucherDefinition.fromJson(e as Map<String, dynamic>)).toList();
});

/// Create voucher state
class CreateVoucherState {
  final bool isLoading;
  final String? error;
  final bool success;

  CreateVoucherState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  CreateVoucherState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return CreateVoucherState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// Create voucher notifier
class CreateVoucherNotifier extends StateNotifier<CreateVoucherState> {
  final Ref _ref;

  CreateVoucherNotifier(this._ref) : super(CreateVoucherState());

  Future<bool> create(Map<String, dynamic> data) async {
    state = CreateVoucherState(isLoading: true);
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      await factory.admin.createVoucher(data);
      state = CreateVoucherState(success: true);
      _ref.invalidate(adminVouchersProvider);
      return true;
    } catch (e) {
      state = CreateVoucherState(error: e.toString());
      return false;
    }
  }

  void reset() => state = CreateVoucherState();
}

final createVoucherProvider =
    StateNotifierProvider<CreateVoucherNotifier, CreateVoucherState>((ref) {
  return CreateVoucherNotifier(ref);
});

/// Voucher Management Screen
class VoucherManagementScreen extends ConsumerWidget {
  const VoucherManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(adminVouchersProvider);

    return AdminScaffold(
      title: 'Quản lý Voucher',
      body: vouchersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(responsivePadding(context)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Chưa có voucher nào'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo Voucher'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.all(responsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${vouchers.length} vouchers',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo Voucher'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Tên')),
                        DataColumn(label: Text('Loại')),
                        DataColumn(label: Text('Điểm')),
                        DataColumn(label: Text('Đã đổi')),
                        DataColumn(label: Text('Trạng thái')),
                        DataColumn(label: Text('Hành động')),
                      ],
                      rows: vouchers.map((v) => DataRow(
                        cells: [
                          DataCell(Text(v.code)),
                          DataCell(Text(v.name)),
                          DataCell(Text(v.voucherType == 'PERCENT_DISCOUNT'
                              ? '${v.discountPercent ?? 0}% Off'
                              : 'Free ${v.serviceType ?? ""}')),
                          DataCell(Text('${v.pointCost}')),
                          DataCell(Text('${v.redemptionCount ?? 0}')),
                          DataCell(_StatusChip(status: v.status)),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  v.status == 'ACTIVE' ? Icons.pause : Icons.play_arrow,
                                  color: v.status == 'ACTIVE' ? Colors.orange : Colors.green,
                                ),
                                tooltip: v.status == 'ACTIVE' ? 'Deactivate' : 'Activate',
                                onPressed: () async {
                                  final newStatus = v.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
                                  try {
                                    final factory = ref.read(apiClientFactoryProvider);
                                    if (factory == null) return;
                                    await factory.admin.updateVoucherStatus(v.id, newStatus);
                                    ref.invalidate(adminVouchersProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Lỗi: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          )),
                        ],
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pointCostCtrl = TextEditingController();
    final discPctCtrl = TextEditingController(text: '5');
    final maxValCtrl = TextEditingController(text: '10000');
    final validityDaysCtrl = TextEditingController(text: '30');
    String voucherType = 'PERCENT_DISCOUNT';
    String serviceType = 'CHARGING';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tạo Voucher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Code (unique)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointCostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Điểm cần đổi',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: validityDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số ngày hiệu lực',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: voucherType,
                  decoration: const InputDecoration(
                    labelText: 'Loại',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PERCENT_DISCOUNT', child: Text('PERCENT_DISCOUNT')),
                    DropdownMenuItem(value: 'FREE_SERVICE', child: Text('FREE_SERVICE')),
                  ],
                  onChanged: (v) => setState(() => voucherType = v ?? 'PERCENT_DISCOUNT'),
                ),
                const SizedBox(height: 8),
                if (voucherType == 'PERCENT_DISCOUNT') ...[
                  TextField(
                    controller: discPctCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Discount %',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: maxValCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Max VND',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (voucherType == 'FREE_SERVICE') ...[
                  DropdownButtonFormField<String>(
                    value: serviceType,
                    decoration: const InputDecoration(
                      labelText: 'Service Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CHARGING', child: Text('CHARGING')),
                      DropdownMenuItem(value: 'BATTERY_SWAP', child: Text('BATTERY_SWAP')),
                    ],
                    onChanged: (v) => setState(() => serviceType = v ?? 'CHARGING'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            Consumer(
              builder: (ctx, ref, _) {
                final state = ref.watch(createVoucherProvider);
                return FilledButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          try {
                            final success = await ref.read(createVoucherProvider.notifier).create({
                              'code': codeCtrl.text,
                              'name': nameCtrl.text,
                              'description': descCtrl.text,
                              'voucherType': voucherType,
                              'pointCost': int.tryParse(pointCostCtrl.text) ?? 0,
                              'validityDays': int.tryParse(validityDaysCtrl.text) ?? 30,
                              if (voucherType == 'PERCENT_DISCOUNT') ...{
                                'discountPercent': int.tryParse(discPctCtrl.text) ?? 5,
                                'maxValueVnd': int.tryParse(maxValCtrl.text) ?? 10000,
                              },
                              if (voucherType == 'FREE_SERVICE') 'serviceType': serviceType,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e')),
                              );
                            }
                          }
                        },
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Tạo'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'INACTIVE':
        color = Colors.orange;
        break;
      case 'ARCHIVED':
        color = Colors.grey;
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
