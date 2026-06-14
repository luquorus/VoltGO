import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../providers/station_search_providers.dart';
import '../repositories/station_search_repository.dart';
import '../widgets/main_scaffold.dart';

/// Create Change Request Screen for Collaborators.
///
/// Supports two station kinds:
///  - CHARGING: requires name, address, lat/lng, operating hours, charging ports
///  - BATTERY_SWAP: requires operating hours, totalBatteries, avgChargePowerKw
///
/// The station search dropdown is currently a free-text field (collaborators
/// know which station they verified), to keep the first iteration lean. A
/// proper dropdown can be wired in later.
class CollabChangeRequestCreateScreen extends ConsumerStatefulWidget {
  const CollabChangeRequestCreateScreen({super.key});

  @override
  ConsumerState<CollabChangeRequestCreateScreen> createState() =>
      _CollabChangeRequestCreateScreenState();
}

class _CollabChangeRequestCreateScreenState
    extends ConsumerState<CollabChangeRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  String _stationKind = 'CHARGING';
  String _type = 'UPDATE_STATION';
  String? _autoFillParking;
  String? _autoFillVisibility;
  String? _autoFillPublicStatus;
  final _stationIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  final _totalBatteriesController = TextEditingController(text: '20');
  final _avgChargePowerKwController = TextEditingController(text: '35.0');

  // Charging ports — list of (powerType, powerKw, count)
  final List<_PortEntry> _ports = [_PortEntry()];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _stationIdController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    _totalBatteriesController.dispose();
    _avgChargePowerKwController.dispose();
    for (final p in _ports) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CollabMainScaffold(
      title: 'New change request',
      showBottomNav: false,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStationKindCard(theme),
              const SizedBox(height: 16),
              _buildTypeCard(theme),
              const SizedBox(height: 16),
              if (_stationKind == 'CHARGING') ..._buildChargingForm(theme) else ..._buildBatterySwapForm(theme),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save as draft',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _handleSubmit,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationKindCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Station type', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Charging'),
                    value: 'CHARGING',
                    groupValue: _stationKind,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _stationKind = v);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Battery swap'),
                    value: 'BATTERY_SWAP',
                    groupValue: _stationKind,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _stationKind = v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Action', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Update'),
                    value: 'UPDATE_STATION',
                    groupValue: _type,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _type = v);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Create'),
                    value: 'CREATE_STATION',
                    groupValue: _type,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _type = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_type == 'UPDATE_STATION') ...[
              AppTextField(
                label: 'Station ID *',
                controller: _stationIdController,
                hint: 'UUID of the station you want to update',
                validator: (v) {
                  if (_type != 'UPDATE_STATION') return null;
                  if (v == null || v.trim().isEmpty) return 'Station ID is required';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _buildStationSearchField(theme),
            ],
          ],
        ),
      ),
    );
  }

  /// Search-by-name field with autocomplete. Picking a result populates
  /// the station ID and the rest of the form via auto-fill.
  Widget _buildStationSearchField(ThemeData theme) {
    return _stationKind == 'CHARGING'
        ? _buildChargingStationSearchField(theme)
        : _buildBatterySwapStationSearchField(theme);
  }

  Widget _buildChargingStationSearchField(ThemeData theme) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(chargingStationSearchProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tìm trạm theo tên (auto-fill)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Gõ tên trạm (≥ 2 ký tự)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                ref.read(chargingStationSearchProvider.notifier).search(v);
              },
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ),
            if (state.results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = state.results[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          if (s.address != null && s.address!.isNotEmpty) s.address!,
                          s.stationId,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: s.supportsBatterySwap
                          ? const Icon(Icons.battery_charging_full, size: 18)
                          : null,
                      onTap: () => _autoFillFromCharging(s),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBatterySwapStationSearchField(ThemeData theme) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(batterySwapStationSearchProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tìm trạm pin theo tên (auto-fill)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 6),
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Gõ tên trạm pin (≥ 2 ký tự)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) {
                ref.read(batterySwapStationSearchProvider.notifier).search(v);
              },
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ),
            if (state.results.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: state.results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = state.results[i];
                    return ListTile(
                      dense: true,
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          if (s.address != null && s.address!.isNotEmpty) s.address!,
                          s.stationId,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _autoFillFromBatterySwap(s),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _autoFillFromCharging(StationSearchItem item) async {
    _stationIdController.text = item.stationId;
    _nameController.text = item.name;
    if (item.address != null) _addressController.text = item.address!;
    if (item.lat != null) _latController.text = item.lat!.toString();
    if (item.lng != null) _lngController.text = item.lng!.toString();
    if (item.operatingHours != null) {
      _operatingHoursController.text = item.operatingHours!;
    }

    // Clear search dropdown but keep typed query
    ref.read(chargingStationSearchProvider.notifier).clear();

    // Fetch full detail to populate ports + battery swap fields
    try {
      final detail =
          await ref.read(chargingStationDetailProvider(item.stationId).future);
      if (!mounted) return;
      if (detail == null) {
        AppToast.showError(context, 'Station id is empty, cannot auto-fill');
        return;
      }
      setState(() {
        _autoFillParking = detail.parking;
        _autoFillVisibility = detail.visibility;
        _autoFillPublicStatus = detail.publicStatus;
        if (detail.ports.isNotEmpty) {
          _ports.clear();
          for (final p in detail.ports) {
            _ports.add(_PortEntry.initial(
              powerType: p.powerType ?? 'DC',
              powerKw: p.powerKw?.toString() ?? '',
              count: p.count?.toString() ?? '1',
            ));
          }
        }
        if (detail.totalBatteries != null) {
          _totalBatteriesController.text = detail.totalBatteries.toString();
        }
        if (detail.avgChargePowerKw != null) {
          _avgChargePowerKwController.text =
              detail.avgChargePowerKw!.toStringAsFixed(1);
        }
      });
      AppToast.showSuccess(context, 'Đã điền thông tin trạm');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Không tải được chi tiết trạm: $e');
    }
  }

  Future<void> _autoFillFromBatterySwap(
      BatterySwapStationSearchItem item) async {
    _stationIdController.text = item.stationId;
    if (item.address != null) _addressController.text = item.address!;

    ref.read(batterySwapStationSearchProvider.notifier).clear();

    try {
      final detail = await ref
          .read(batterySwapStationDetailProvider(item.stationId).future);
      if (!mounted) return;
      if (detail == null) {
        AppToast.showError(context, 'Station id is empty, cannot auto-fill');
        return;
      }
      setState(() {
        if (detail.totalBatteries != null) {
          _totalBatteriesController.text = detail.totalBatteries.toString();
        }
        if (detail.avgChargePowerKw != null) {
          _avgChargePowerKwController.text =
              detail.avgChargePowerKw!.toStringAsFixed(1);
        }
        if (detail.operatingHours != null) {
          _operatingHoursController.text = detail.operatingHours!;
        }
        if (detail.lat != null) {
          _latController.text = detail.lat!.toString();
        }
        if (detail.lng != null) {
          _lngController.text = detail.lng!.toString();
        }
      });
      AppToast.showSuccess(context, 'Đã điền thông tin trạm pin');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Không tải được chi tiết trạm pin: $e');
    }
  }

  List<Widget> _buildChargingForm(ThemeData theme) {
    return [
      AppTextField(
        label: 'Station name *',
        controller: _nameController,
        validator: (v) =>
            (v == null || v.trim().length < 3) ? 'Name must be at least 3 chars' : null,
      ),
      const SizedBox(height: 12),
      AppTextField(
        label: 'Address',
        controller: _addressController,
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: 'Latitude *',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d < -90 || d > 90) return 'Invalid latitude';
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: 'Longitude *',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
              ],
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d < -180 || d > 180) return 'Invalid longitude';
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      AppTextField(
        label: 'Operating hours',
        controller: _operatingHoursController,
        hint: 'e.g., 24/7, 06:00-22:00',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Text('Charging ports', style: theme.textTheme.titleMedium),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _ports.add(_PortEntry())),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
            label: const Text('Add port'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ..._ports.asMap().entries.map((e) => _buildPortCard(theme, e.key, e.value)),
    ];
  }

  Widget _buildPortCard(ThemeData theme, int index, _PortEntry port) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: port.powerType,
                    decoration: const InputDecoration(
                      labelText: 'Power type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AC', child: Text('AC')),
                      DropdownMenuItem(value: 'DC', child: Text('DC')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => port.powerType = v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: port.powerKwController,
                    decoration: InputDecoration(
                      labelText: port.powerType == 'DC' ? 'Power (kW) *' : 'Power (kW)',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (v) {
                      if (port.powerType == 'DC') {
                        final d = double.tryParse((v ?? '').trim());
                        if (d == null || d <= 0) return 'Required > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: port.countController,
                    decoration: const InputDecoration(
                      labelText: 'Count *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'Min 1';
                      return null;
                    },
                  ),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trash, size: 14, color: Colors.red),
                  onPressed: _ports.length == 1
                      ? null
                      : () => setState(() {
                            port.dispose();
                            _ports.removeAt(index);
                          }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBatterySwapForm(ThemeData theme) {
    return [
      AppTextField(
        label: 'Operating hours *',
        controller: _operatingHoursController,
        hint: 'e.g., 06:00-22:00',
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _totalBatteriesController,
        decoration: const InputDecoration(
          labelText: 'Total batteries *',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final n = int.tryParse((v ?? '').trim());
          if (n == null || n <= 0) return 'Must be > 0';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _avgChargePowerKwController,
        decoration: const InputDecoration(
          labelText: 'Avg charge power (kW) *',
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        validator: (v) {
          final d = double.tryParse((v ?? '').trim());
          if (d == null || d <= 0) return 'Must be > 0';
          return null;
        },
      ),
    ];
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'Please fix the errors first');
      return;
    }

    if (_type == 'UPDATE_STATION' &&
        _stationIdController.text.trim().isEmpty) {
      AppToast.showError(context, 'Station ID is required for update');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_stationKind == 'CHARGING') {
        await _submitCharging();
      } else {
        await _submitBatterySwap();
      }
      if (!mounted) return;
      AppToast.showSuccess(context, 'Draft saved');
      ref.invalidate(changeRequestListProvider);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitCharging() async {
    final repo = ref.read(changeRequestRepositoryProvider);
    final stationData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? 'Address not provided'
          : _addressController.text.trim(),
      'location': {
        'lat': double.parse(_latController.text.trim()),
        'lng': double.parse(_lngController.text.trim()),
      },
      'parking': _autoFillParking ?? 'UNKNOWN',
      'visibility': _autoFillVisibility ?? 'PUBLIC',
      'publicStatus': _autoFillPublicStatus ?? 'ACTIVE',
      'services': [
        {
          'type': 'CHARGING',
          'chargingPorts': _ports
              .map((p) => {
                    'powerType': p.powerType,
                    'count': int.parse(p.countController.text.trim()),
                    if (p.powerType == 'DC' &&
                        p.powerKwController.text.trim().isNotEmpty)
                      'powerKw':
                          double.parse(p.powerKwController.text.trim()),
                  })
              .toList(),
        },
      ],
    };
    if (_operatingHoursController.text.trim().isNotEmpty) {
      stationData['operatingHours'] = _operatingHoursController.text.trim();
    }
    final data = <String, dynamic>{
      'type': _type,
      if (_type == 'UPDATE_STATION')
        'stationId': _stationIdController.text.trim(),
      'stationData': stationData,
    };
    await repo.createChangeRequest(data);
  }

  Future<void> _submitBatterySwap() async {
    final repo = ref.read(batterySwapChangeRequestRepositoryProvider);
    final data = <String, dynamic>{
      'type': _type == 'CREATE_STATION'
          ? 'CREATE_BATTERY_SWAP_STATION'
          : 'UPDATE_BATTERY_SWAP_STATION',
      if (_type == 'UPDATE_STATION')
        'stationId': _stationIdController.text.trim(),
      'totalBatteries': int.parse(_totalBatteriesController.text.trim()),
      'avgChargePowerKw': double.parse(_avgChargePowerKwController.text.trim()),
      'operatingHours': _operatingHoursController.text.trim(),
      'pileTemplates': [],
    };
    await repo.createChangeRequest(data);
  }
}

class _PortEntry {
  String powerType;
  final TextEditingController powerKwController;
  final TextEditingController countController;

  _PortEntry()
      : powerType = 'DC',
        powerKwController = TextEditingController(),
        countController = TextEditingController(text: '1');

  _PortEntry.initial({
    required String powerType,
    required String powerKw,
    required String count,
  })  : powerType = powerType,
        powerKwController = TextEditingController(text: powerKw),
        countController = TextEditingController(text: count);

  void dispose() {
    powerKwController.dispose();
    countController.dispose();
  }
}
