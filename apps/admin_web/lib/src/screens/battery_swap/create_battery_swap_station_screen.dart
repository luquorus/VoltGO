import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/battery_swap_station_providers.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';
import '../../utils/responsive_utils.dart';

/// Create Battery Swap Station Screen
class CreateBatterySwapStationScreen extends ConsumerStatefulWidget {
  const CreateBatterySwapStationScreen({super.key});

  @override
  ConsumerState<CreateBatterySwapStationScreen> createState() =>
      _CreateBatterySwapStationScreenState();
}

class _CreateBatterySwapStationScreenState
    extends ConsumerState<CreateBatterySwapStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _operatingHoursController =
      TextEditingController(text: '06:00-22:00');
  final _parkingFeeController = TextEditingController();
  final _totalBatteriesController = TextEditingController(text: '20');
  final _avgChargePowerKwController = TextEditingController(text: '35.0');
  final _batteryCapacityKwhController = TextEditingController(text: '60.0');
  final _parkingController = TextEditingController(text: 'FREE');
  final _noteController = TextEditingController();

  // Custom pile layout (optional). When null/empty → use default (6 slots/pile).
  final _useCustomPileLayout = ValueNotifier<bool>(false);
  final _pileCountController = TextEditingController(text: '4');
  final _slotsPerPileController = TextEditingController(text: '6');
  final _layoutBatteryCapacityKwhController = TextEditingController(text: '60.0');

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    _parkingFeeController.dispose();
    _totalBatteriesController.dispose();
    _avgChargePowerKwController.dispose();
    _batteryCapacityKwhController.dispose();
    _parkingController.dispose();
    _noteController.dispose();
    _useCustomPileLayout.dispose();
    _pileCountController.dispose();
    _slotsPerPileController.dispose();
    _layoutBatteryCapacityKwhController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      final stationData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': double.parse(_latController.text.trim()),
        'longitude': double.parse(_lngController.text.trim()),
        'operatingHours': _operatingHoursController.text.trim(),
        'totalBatteries': int.parse(_totalBatteriesController.text.trim()),
        'avgChargePowerKw': double.parse(_avgChargePowerKwController.text.trim()),
        'batteryCapacityKwh': double.parse(_batteryCapacityKwhController.text.trim()),
        'parking': _parkingController.text.trim(),
        'publishImmediately': true,
      };

      // Add optional fields if provided
      final parkingFee = _parkingFeeController.text.trim();
      if (parkingFee.isNotEmpty) {
        stationData['parkingFee'] = double.tryParse(parkingFee);
      }

      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        stationData['note'] = note;
      }

      // Custom pile layout (optional). Only include if user toggled it on AND
      // pileCount × slotsPerPile matches totalBatteries.
      if (_useCustomPileLayout.value) {
        final pileCount = int.tryParse(_pileCountController.text.trim()) ?? 0;
        final slotsPerPile = int.tryParse(_slotsPerPileController.text.trim()) ?? 0;
        final totalBatteries = int.parse(_totalBatteriesController.text.trim());
        if (pileCount > 0 && slotsPerPile > 0 && pileCount * slotsPerPile == totalBatteries) {
          final layoutCapacity =
              double.tryParse(_layoutBatteryCapacityKwhController.text.trim()) ??
                  double.parse(_batteryCapacityKwhController.text.trim());
          final piles = <Map<String, dynamic>>[];
          for (var i = 0; i < pileCount; i++) {
            piles.add({
              'pileIndex': i + 1,
              'slotsPerPile': slotsPerPile,
            });
          }
          stationData['pileTemplates'] = piles;
          stationData['batteryCapacityKwh'] = layoutCapacity;
        } else {
          throw Exception(
              'Pile layout mismatch: $pileCount × $slotsPerPile != $totalBatteries');
        }
      }

      await factory.admin.createBatterySwapStation(stationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Battery swap station created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
        ref.invalidate(batterySwapStationsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating station: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Create Battery Swap Station',
      body: SingleChildScrollView(
        padding: responsivePadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Station Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Station name is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Station name must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 400) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _latController,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Latitude is required';
                                    final lat = double.tryParse(value);
                                    if (lat == null || lat < -90 || lat > 90) return 'Must be between -90 and 90';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _lngController,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) return 'Longitude is required';
                                    final lng = double.tryParse(value);
                                    if (lng == null || lng < -180 || lng > 180) return 'Must be between -180 and 180';
                                    return null;
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: TextFormField(
                                controller: _latController,
                                decoration: const InputDecoration(labelText: 'Latitude *', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Latitude is required';
                                  final lat = double.tryParse(value);
                                  if (lat == null || lat < -90 || lat > 90) return 'Must be between -90 and 90';
                                  return null;
                                },
                              )),
                              const SizedBox(width: 16),
                              Expanded(child: TextFormField(
                                controller: _lngController,
                                decoration: const InputDecoration(labelText: 'Longitude *', border: OutlineInputBorder()),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Longitude is required';
                                  final lng = double.tryParse(value);
                                  if (lng == null || lng < -180 || lng > 180) return 'Must be between -180 and 180';
                                  return null;
                                },
                              )),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Operating Info
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operating Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _operatingHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Operating Hours',
                          hintText: 'e.g., 06:00-22:00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _parkingFeeController,
                        decoration: const InputDecoration(
                          labelText: 'Parking Fee (optional)',
                          hintText: 'Leave empty if no parking fee',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final fee = double.tryParse(value.trim());
                            if (fee == null || fee < 0) {
                              return 'Invalid parking fee';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _parkingController.text,
                        decoration: const InputDecoration(
                          labelText: 'Parking Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'FREE', child: Text('Free parking')),
                          DropdownMenuItem(value: 'PAID', child: Text('Paid parking')),
                          DropdownMenuItem(
                              value: 'STREET_PARKING',
                              child: Text('Street parking')),
                          DropdownMenuItem(
                              value: 'UNKNOWN', child: Text('Unknown / Other')),
                        ],
                        onChanged: (v) {
                          if (v != null) _parkingController.text = v;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Battery Info
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _totalBatteriesController,
                        decoration: const InputDecoration(
                          labelText: 'Total Batteries *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Total batteries is required';
                          }
                          final n = int.tryParse(value.trim());
                          if (n == null || n < 1) {
                            return 'Must be at least 1';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _avgChargePowerKwController,
                        decoration: const InputDecoration(
                          labelText: 'Avg Charge Power (kW) *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Average charge power is required';
                          }
                          final n = double.tryParse(value.trim());
                          if (n == null || n <= 0) {
                            return 'Must be greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _batteryCapacityKwhController,
                        decoration: const InputDecoration(
                          labelText: 'Battery Capacity per slot (kWh) *',
                          helperText: 'Default 60.0 kWh. Used for all slots unless overridden below.',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Battery capacity is required';
                          }
                          final n = double.tryParse(value.trim());
                          if (n == null || n < 1) {
                            return 'Must be at least 1 kWh';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: _useCustomPileLayout,
                        builder: (context, useCustom, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: const Text('Use custom pile layout'),
                              subtitle: Text(useCustom
                                  ? 'Pile × slots must multiply to totalBatteries'
                                  : 'Default: 6 slots per pile'),
                              value: useCustom,
                              onChanged: (v) {
                                _useCustomPileLayout.value = v;
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            if (useCustom) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _pileCountController,
                                      decoration: const InputDecoration(
                                        labelText: 'Pile count',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (!useCustom) return null;
                                        final n = int.tryParse(value?.trim() ?? '');
                                        if (n == null || n < 1) {
                                          return 'Must be >= 1';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _slotsPerPileController,
                                      decoration: const InputDecoration(
                                        labelText: 'Slots per pile',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (!useCustom) return null;
                                        final n = int.tryParse(value?.trim() ?? '');
                                        if (n == null || n < 1) {
                                          return 'Must be >= 1';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _layoutBatteryCapacityKwhController,
                                decoration: const InputDecoration(
                                  labelText: 'Slot capacity in this layout (kWh)',
                                  helperText:
                                      'Optional. Defaults to batteryCapacityKwh above.',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Note
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: 'Any additional notes about this station',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('Creating...'),
                            ],
                          )
                        : const Text('Create Station'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
