import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_station.dart';
import '../providers/station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../utils/responsive_utils.dart';

/// Create Station Screen
class CreateStationScreen extends ConsumerStatefulWidget {
  final AdminStation? station;

  const CreateStationScreen({super.key, this.station});

  @override
  ConsumerState<CreateStationScreen> createState() => _CreateStationScreenState();
}

class _CreateStationScreenState extends ConsumerState<CreateStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  
  ParkingType _parking = ParkingType.unknown;
  VisibilityType _visibility = VisibilityType.public;
  PublicStatus _publicStatus = PublicStatus.active;
  bool _publishImmediately = true;
  
  // Charging ports
  final List<ChargingPortInput> _ports = [];

  bool _enableBatterySwap = false;
  final _swapTotalController = TextEditingController(text: '20');
  final _swapAvgPowerController = TextEditingController(text: '35');

  bool get _isEditMode => widget.station != null;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      final s = widget.station!;
      _nameController.text = s.name ?? '';
      _addressController.text = s.address ?? '';
      _latController.text = s.lat?.toString() ?? '';
      _lngController.text = s.lng?.toString() ?? '';
      _operatingHoursController.text = s.operatingHours ?? '';
      
      if (s.parking != null) _parking = s.parking!;
      if (s.visibility != null) _visibility = s.visibility!;
      if (s.publicStatus != null) _publicStatus = s.publicStatus!;
      
      // Populate ports from the first charging service
      final chargingService = s.services.where((srv) => srv.type == ServiceType.charging).firstOrNull;
      if (chargingService != null && chargingService.chargingPorts.isNotEmpty) {
        for (var port in chargingService.chargingPorts) {
          final p = ChargingPortInput();
          p.powerType = port.powerType;
          p.powerKw = port.powerKw;
          p.count = port.portCount;
          _ports.add(p);
        }
      }

      final swapService =
          s.services.where((srv) => srv.type == ServiceType.batterySwap).firstOrNull;
      if (swapService != null) {
        _enableBatterySwap = true;
        if (swapService.totalBatteries != null) {
          _swapTotalController.text = '${swapService.totalBatteries}';
        }
        if (swapService.avgChargePowerKw != null) {
          _swapAvgPowerController.text = '${swapService.avgChargePowerKw}';
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    _swapTotalController.dispose();
    _swapAvgPowerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final swapTotal = int.tryParse(_swapTotalController.text.trim());
    final swapAvg = double.tryParse(_swapAvgPowerController.text.trim());
    final swapOk = _enableBatterySwap &&
        swapTotal != null &&
        swapTotal > 0 &&
        swapAvg != null &&
        swapAvg > 0;
    final hasCharging = _ports.isNotEmpty;

    if (!hasCharging && !swapOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add at least one charging port or enable battery swap with valid values'),
        ),
      );
      return;
    }

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      final services = <Map<String, dynamic>>[];
      if (hasCharging) {
        services.add({
          'type': 'CHARGING',
          'chargingPorts': _ports
              .map((port) => {
                    'powerType': port.powerType.name.toUpperCase(),
                    'powerKw': port.powerKw,
                    'count': port.count,
                  })
              .toList(),
        });
      }
      if (swapOk) {
        services.add({
          'type': 'BATTERY_SWAP',
          'totalBatteries': swapTotal,
          'avgChargePowerKw': swapAvg,
        });
      }

      // Build station data
      final stationData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'location': {
          'lat': double.parse(_latController.text),
          'lng': double.parse(_lngController.text),
        },
        'operatingHours': _operatingHoursController.text.trim(),
        'parking': _parking.name.toUpperCase(),
        'visibility': _visibility.name.toUpperCase(),
        'publicStatus': _publicStatus.name.toUpperCase(),
        'services': services,
      };

      final request = {
        'stationData': stationData,
        'publishImmediately': _publishImmediately,
      };

      if (_isEditMode) {
        await factory.admin.updateStation(widget.station!.stationId, request);
      } else {
        await factory.admin.createStation(request);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Station updated successfully' : 'Station created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
        ref.invalidate(stationsProvider((page: 0, size: 20, search: null)));
        if (_isEditMode) {
          ref.invalidate(stationProvider(widget.station!.stationId));
        }
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
    }
  }

  void _addPort() {
    setState(() {
      _ports.add(ChargingPortInput());
    });
  }

  void _removePort(int index) {
    setState(() {
      _ports.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: _isEditMode ? 'Edit Station' : 'Create Station',
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
                          fontSize: isMobile(context) ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Latitude is required';
                                    }
                                    final lat = double.tryParse(value);
                                    if (lat == null || lat < -90 || lat > 90) {
                                      return 'Latitude must be between -90 and 90';
                                    }
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
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Longitude is required';
                                    }
                                    final lng = double.tryParse(value);
                                    if (lng == null || lng < -180 || lng > 180) {
                                      return 'Longitude must be between -180 and 180';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latController,
                                  decoration: const InputDecoration(
                                    labelText: 'Latitude *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Latitude is required';
                                    }
                                    final lat = double.tryParse(value);
                                    if (lat == null || lat < -90 || lat > 90) {
                                      return 'Latitude must be between -90 and 90';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _lngController,
                                  decoration: const InputDecoration(
                                    labelText: 'Longitude *',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Longitude is required';
                                    }
                                    final lng = double.tryParse(value);
                                    if (lng == null || lng < -180 || lng > 180) {
                                      return 'Longitude must be between -180 and 180';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _operatingHoursController,
                        decoration: const InputDecoration(
                          labelText: 'Operating Hours',
                          hintText: 'e.g., 24/7 or 08:00-22:00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile(context) ? 16 : 24),

              // Settings
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile(context) ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ParkingType>(
                        value: _parking,
                        decoration: const InputDecoration(
                          labelText: 'Parking Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: ParkingType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _parking = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<VisibilityType>(
                        value: _visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility *',
                          border: OutlineInputBorder(),
                        ),
                        items: VisibilityType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _visibility = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<PublicStatus>(
                        value: _publicStatus,
                        decoration: const InputDecoration(
                          labelText: 'Public Status *',
                          border: OutlineInputBorder(),
                        ),
                        items: PublicStatus.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _publicStatus = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Publish Immediately'),
                        subtitle: const Text('If checked, station will be published right away'),
                        value: _publishImmediately,
                        onChanged: (value) {
                          setState(() {
                            _publishImmediately = value ?? true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Charging Ports
              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Text(
                        'Charging ports',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile(context) ? 16 : null,
                        ),
                      ),
                          ElevatedButton.icon(
                            onPressed: _addPort,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Port'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_ports.isEmpty)
                        Text(
                          _enableBatterySwap
                              ? 'Optional — add ports if this station offers charging.'
                              : 'No charging ports yet. Add ports or enable battery swap below.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _enableBatterySwap
                                ? theme.colorScheme.onSurface.withOpacity(0.65)
                                : theme.colorScheme.error,
                          ),
                        ),
                      ...List.generate(_ports.length, (index) {
                        return _buildPortInput(theme, index);
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery swap service',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile(context) ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable battery swap'),
                        value: _enableBatterySwap,
                        onChanged: (v) => setState(() => _enableBatterySwap = v),
                      ),
                      if (_enableBatterySwap) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _swapTotalController,
                          decoration: const InputDecoration(
                            labelText: 'Total batteries *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!_enableBatterySwap) return null;
                            final n = int.tryParse(value?.trim() ?? '');
                            if (n == null || n <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _swapAvgPowerController,
                          decoration: const InputDecoration(
                            labelText: 'Avg charge power (kW) *',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (!_enableBatterySwap) return null;
                            final n = double.tryParse(value?.trim() ?? '');
                            if (n == null || n <= 0) return 'Must be > 0';
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isEditMode ? 'Save Changes' : 'Create Station'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortInput(ThemeData theme, int index) {
    final port = _ports[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Port ${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removePort(index),
                  color: theme.colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PowerType>(
              value: port.powerType,
              decoration: const InputDecoration(
                labelText: 'Power Type *',
                border: OutlineInputBorder(),
              ),
              items: PowerType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    port.powerType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (port.powerType == PowerType.dc)
              TextFormField(
                initialValue: port.powerKw?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Power (kW) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  port.powerKw = double.tryParse(value);
                },
                validator: (value) {
                  if (port.powerType == PowerType.dc) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Power is required for DC ports';
                    }
                    final kw = double.tryParse(value);
                    if (kw == null || kw <= 0) {
                      return 'Power must be greater than 0';
                    }
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: port.count.toString(),
              decoration: const InputDecoration(
                labelText: 'Port Count *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                port.count = int.tryParse(value) ?? 1;
              },
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Port count is required';
                }
                final count = int.tryParse(value);
                if (count == null || count < 1) {
                  return 'Port count must be at least 1';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChargingPortInput {
  PowerType powerType = PowerType.dc;
  double? powerKw;
  int count = 1;
}

