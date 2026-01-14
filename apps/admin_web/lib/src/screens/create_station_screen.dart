import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_station.dart';
import '../providers/station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Create Station Screen
class CreateStationScreen extends ConsumerStatefulWidget {
  const CreateStationScreen({super.key});

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

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_ports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one charging port')),
      );
      return;
    }

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      // Build services
      final services = [
        {
          'type': 'CHARGING',
          'chargingPorts': _ports.map((port) => {
            'powerType': port.powerType.name.toUpperCase(),
            'powerKw': port.powerKw,
            'count': port.count,
          }).toList(),
        }
      ];

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

      await factory.admin.createStation(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
        ref.invalidate(stationsProvider((page: 0, size: 20)));
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
      title: 'Create Station',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),

              // Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Charging Ports *',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
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
                          'No charging ports added. Please add at least one.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
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
                    child: const Text('Create Station'),
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

