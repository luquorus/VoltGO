import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/change_request_providers.dart';
import '../repositories/change_request_repository.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/station_search_dropdown.dart';

/// Change Request Create Screen
class ChangeRequestCreateScreen extends ConsumerStatefulWidget {
  const ChangeRequestCreateScreen({super.key});

  @override
  ConsumerState<ChangeRequestCreateScreen> createState() => _ChangeRequestCreateScreenState();
}

class _ChangeRequestCreateScreenState extends ConsumerState<ChangeRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Form fields
  String? _type; // CREATE_STATION or UPDATE_STATION
  String? _selectedStationId; // Selected station ID for UPDATE_STATION
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  String? _parking; // PAID, FREE, UNKNOWN
  String? _visibility; // PUBLIC, PRIVATE, RESTRICTED
  String? _publicStatus; // ACTIVE, INACTIVE, MAINTENANCE
  
  // Services
  List<ServiceData> _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];
  
  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _isLoadingStation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MainScaffold(
      title: 'Create Station Proposal',
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              _buildTypeSelector(theme),
              const SizedBox(height: 24),
              
              // Station Selection (only for UPDATE)
              if (_type == 'UPDATE_STATION') ...[
                StationSearchDropdown(
                  onStationSelected: (stationId) {
                    if (stationId != null) {
                      _loadStationData(stationId);
                    } else {
                      setState(() {
                        _selectedStationId = null;
                        _clearForm();
                      });
                    }
                  },
                  initialStationId: _selectedStationId,
                  enabled: !_isSubmitting && !_isLoadingStation,
                  validator: (value) {
                    if (_type == 'UPDATE_STATION' && _selectedStationId == null) {
                      return 'Please select a station';
                    }
                    return null;
                  },
                ),
                if (_isLoadingStation) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Loading station data...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
              ],
              
              // Station Data Section
              Text(
                'Station Information',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                label: 'Station Name *',
                controller: _nameController,
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  if (value.length > 255) {
                    return 'Name must be at most 255 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                label: 'Address',
                controller: _addressController,
                enabled: !_isSubmitting,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Location
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SecondaryButton(
                    label: _isGettingLocation ? 'Getting...' : 'Use Current Location',
                    onPressed: _isSubmitting || _isGettingLocation ? null : _getCurrentLocation,
                    isLoading: _isGettingLocation,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Latitude is required';
                        }
                        final lat = double.tryParse(value.trim());
                        if (lat == null) {
                          return 'Invalid latitude';
                        }
                        if (lat < -90 || lat > 90) {
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
                      enabled: !_isSubmitting,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Longitude is required';
                        }
                        final lng = double.tryParse(value.trim());
                        if (lng == null) {
                          return 'Invalid longitude';
                        }
                        if (lng < -180 || lng > 180) {
                          return 'Longitude must be between -180 and 180';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                label: 'Operating Hours',
                controller: _operatingHoursController,
                enabled: !_isSubmitting,
                hint: 'e.g., 24/7, Mon-Fri 8AM-6PM',
              ),
              const SizedBox(height: 16),
              
              // Parking
              _buildDropdown(
                theme,
                'Parking Type',
                _parking,
                ['PAID', 'FREE', 'UNKNOWN'],
                (value) => setState(() => _parking = value),
              ),
              const SizedBox(height: 16),
              
              // Visibility
              _buildDropdown(
                theme,
                'Visibility',
                _visibility,
                ['PUBLIC', 'PRIVATE', 'RESTRICTED'],
                (value) => setState(() => _visibility = value),
              ),
              const SizedBox(height: 16),
              
              // Public Status
              _buildDropdown(
                theme,
                'Public Status',
                _publicStatus,
                ['ACTIVE', 'INACTIVE', 'MAINTENANCE'],
                (value) => setState(() => _publicStatus = value),
              ),
              const SizedBox(height: 24),
              
              // Services Section
              Text(
                'Services',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Add services for this station (optional)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              ..._services.asMap().entries.map((entry) {
                final index = entry.key;
                final service = entry.value;
                return _buildServiceEditor(theme, index, service);
              }),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'Add Service',
                onPressed: _isSubmitting ? null : () {
                  setState(() {
                    _services.add(ServiceData(type: 'CHARGING', chargingPorts: []));
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Images Section
              Text(
                'Photos',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload photos of the station (optional)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              // Submit Button
              PrimaryButton(
                label: 'Create Station Proposal',
                onPressed: _isSubmitting ? null : _handleSubmit,
                isLoading: _isSubmitting,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Type *',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Create Station'),
                    value: 'CREATE_STATION',
                    groupValue: _type,
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() {
                        _type = value;
                        _selectedStationId = null;
                        _clearForm(); // Clear form when switching to CREATE
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Update Station'),
                    value: 'UPDATE_STATION',
                    groupValue: _type,
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() {
                        _type = value;
                        _selectedStationId = null;
                        // Don't clear form when switching to UPDATE - user might have filled some fields
                      });
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

  Widget _buildDropdown(
    ThemeData theme,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option.replaceAll('_', ' ')),
        );
      }).toList(),
      onChanged: _isSubmitting ? null : onChanged,
    );
  }

  Widget _buildServiceEditor(ThemeData theme, int index, ServiceData service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: service.type,
                    decoration: InputDecoration(
                      labelText: 'Service Type *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: ['CHARGING', 'PARKING', 'RESTROOM', 'CAFE', 'OTHER']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type.replaceAll('_', ' ')),
                            ))
                        .toList(),
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() {
                        _services[index] = ServiceData(
                          type: value!,
                          chargingPorts: service.type == 'CHARGING' && value != 'CHARGING'
                              ? []
                              : service.chargingPorts,
                        );
                      });
                    },
                  ),
                ),
                if (_services.length > 1)
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.trash),
                    color: Colors.red,
                    onPressed: _isSubmitting ? null : () {
                      setState(() {
                        _services.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            if (service.type == 'CHARGING') ...[
              const SizedBox(height: 16),
              Text(
                'Charging Ports',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...service.chargingPorts.asMap().entries.map((entry) {
                final portIndex = entry.key;
                final port = entry.value;
                return _buildChargingPortEditor(theme, index, portIndex, port);
              }),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Add Charging Port',
                onPressed: _isSubmitting ? null : () {
                  setState(() {
                    _services[index].chargingPorts.add(ChargingPortData(
                      powerType: 'DC',
                      powerKw: null,
                      count: 1,
                    ));
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChargingPortEditor(
    ThemeData theme,
    int serviceIndex,
    int portIndex,
    ChargingPortData port,
  ) {
    final powerKwController = TextEditingController(
      text: port.powerKw?.toString() ?? '',
    );
    final countController = TextEditingController(
      text: port.count.toString(),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: port.powerType,
                    decoration: InputDecoration(
                      labelText: 'Power Type *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    items: ['DC', 'AC']
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() {
                        _services[serviceIndex].chargingPorts[portIndex] = ChargingPortData(
                          powerType: value!,
                          powerKw: value == 'DC' ? port.powerKw : null,
                          count: port.count,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: powerKwController,
                    decoration: InputDecoration(
                      labelText: port.powerType == 'DC' ? 'Power (kW) *' : 'Power (kW)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    enabled: !_isSubmitting,
                    validator: (value) {
                      // Required for DC, optional for AC
                      if (port.powerType == 'DC') {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required for DC';
                        }
                        final powerKw = double.tryParse(value.trim());
                        if (powerKw == null || powerKw <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final powerKw = double.tryParse(value);
                      setState(() {
                        _services[serviceIndex].chargingPorts[portIndex] = ChargingPortData(
                          powerType: port.powerType,
                          powerKw: powerKw,
                          count: port.count,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: countController,
                    decoration: InputDecoration(
                      labelText: 'Count *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    enabled: !_isSubmitting,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final count = int.tryParse(value);
                      if (count == null || count < 1) {
                        return 'Must be >= 1';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final count = int.tryParse(value);
                      if (count != null && count >= 1) {
                        setState(() {
                          _services[serviceIndex].chargingPorts[portIndex] = ChargingPortData(
                            powerType: port.powerType,
                            powerKw: port.powerKw,
                            count: count,
                          );
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
                  color: Colors.red,
                  onPressed: _isSubmitting ? null : () {
                    setState(() {
                      _services[serviceIndex].chargingPorts.removeAt(portIndex);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.showError(context, 'Location permission denied');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.showError(context, 'Location permission permanently denied. Please enable in settings.');
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });

      if (mounted) {
        AppToast.showSuccess(context, 'Location retrieved successfully');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to get location: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _loadStationData(String stationId) async {
    setState(() {
      _isLoadingStation = true;
      _selectedStationId = stationId;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      final stationData = await factory.ev.getStation(stationId);

      if (mounted) {
        // Fill form fields with station data
        _nameController.text = stationData['name'] as String? ?? '';
        _addressController.text = stationData['address'] as String? ?? '';
        
        final lat = stationData['lat'] as double?;
        final lng = stationData['lng'] as double?;
        if (lat != null) {
          _latController.text = lat.toStringAsFixed(6);
        }
        if (lng != null) {
          _lngController.text = lng.toStringAsFixed(6);
        }

        _operatingHoursController.text = stationData['operatingHours'] as String? ?? '';
        _parking = stationData['parking'] as String?;
        _visibility = stationData['visibility'] as String?;
        _publicStatus = stationData['publicStatus'] as String?;

        // Load services and charging ports
        final ports = stationData['ports'] as List<dynamic>? ?? [];
        if (ports.isNotEmpty) {
          // Group ports by power type and create charging ports
          final chargingPorts = ports.map((port) {
            final portData = port as Map<String, dynamic>;
            return ChargingPortData(
              powerType: portData['powerType'] as String? ?? 'AC',
              powerKw: portData['powerKw'] != null 
                  ? (portData['powerKw'] as num).toDouble() 
                  : null,
              count: portData['count'] as int? ?? 1,
            );
          }).toList();

          setState(() {
            _services = [
              ServiceData(
                type: 'CHARGING',
                chargingPorts: chargingPorts,
              ),
            ];
          });
        } else {
          // No ports, create default service
          setState(() {
            _services = [
              ServiceData(type: 'CHARGING', chargingPorts: []),
            ];
          });
        }

        setState(() {
          _isLoadingStation = false;
        });

        if (mounted) {
          AppToast.showSuccess(context, 'Station data loaded successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStation = false;
          _selectedStationId = null;
        });
        AppToast.showError(context, 'Failed to load station data: ${e.toString()}');
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _latController.clear();
    _lngController.clear();
    _operatingHoursController.clear();
    _parking = null;
    _visibility = null;
    _publicStatus = null;
    setState(() {
      _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate type
    if (_type == null) {
      AppToast.showError(context, 'Please select request type');
      return;
    }

    // Validate name (required)
    if (_nameController.text.trim().isEmpty) {
      AppToast.showError(context, 'Station name is required');
      return;
    }

    // Validate latitude (required)
    if (_latController.text.trim().isEmpty) {
      AppToast.showError(context, 'Latitude is required');
      return;
    }
    final lat = double.tryParse(_latController.text.trim());
    if (lat == null || lat < -90 || lat > 90) {
      AppToast.showError(context, 'Invalid latitude');
      return;
    }

    // Validate longitude (required)
    if (_lngController.text.trim().isEmpty) {
      AppToast.showError(context, 'Longitude is required');
      return;
    }
    final lng = double.tryParse(_lngController.text.trim());
    if (lng == null || lng < -180 || lng > 180) {
      AppToast.showError(context, 'Invalid longitude');
      return;
    }

    // Validate charging ports
    for (int i = 0; i < _services.length; i++) {
      final service = _services[i];
      if (service.type == 'CHARGING') {
        if (service.chargingPorts.isEmpty) {
          AppToast.showError(context, 'Service ${i + 1}: At least one charging port is required');
          return;
        }
        for (int j = 0; j < service.chargingPorts.length; j++) {
          final port = service.chargingPorts[j];
          if (port.powerType == null || port.powerType!.isEmpty) {
            AppToast.showError(context, 'Service ${i + 1}, Port ${j + 1}: Power type is required');
            return;
          }
          if (port.count < 1) {
            AppToast.showError(context, 'Service ${i + 1}, Port ${j + 1}: Count must be >= 1');
            return;
          }
          if (port.powerType == 'DC' && (port.powerKw == null || port.powerKw! <= 0)) {
            AppToast.showError(context, 'Service ${i + 1}, Port ${j + 1}: Power (kW) is required and must be > 0 for DC');
            return;
          }
        }
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(changeRequestRepositoryProvider);
      
      // Build station data with defaults for required fields
      final stationData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim().isNotEmpty 
            ? _addressController.text.trim() 
            : 'Address not provided',
        'location': {
          'lat': double.parse(_latController.text.trim()),
          'lng': double.parse(_lngController.text.trim()),
        },
        'parking': _parking ?? 'UNKNOWN',
        'visibility': _visibility ?? 'PUBLIC',
        'publicStatus': _publicStatus ?? 'ACTIVE',
        'services': _services.isNotEmpty 
            ? _services.map((service) {
                final serviceData = <String, dynamic>{
                  'type': service.type,
                };
                if (service.type == 'CHARGING' && service.chargingPorts.isNotEmpty) {
                  serviceData['chargingPorts'] = service.chargingPorts.map((port) {
                    final portData = <String, dynamic>{
                      'powerType': port.powerType,
                      'count': port.count,
                    };
                    if (port.powerKw != null) {
                      portData['powerKw'] = port.powerKw;
                    }
                    return portData;
                  }).toList();
                }
                return serviceData;
              }).toList()
            : [
                {
                  'type': 'CHARGING',
                  'chargingPorts': [
                    {
                      'powerType': 'AC',
                      'count': 1,
                    }
                  ]
                }
              ],
      };

      if (_operatingHoursController.text.trim().isNotEmpty) {
        stationData['operatingHours'] = _operatingHoursController.text.trim();
      }

      // Validate station selection for UPDATE_STATION
      if (_type == 'UPDATE_STATION' && _selectedStationId == null) {
        AppToast.showError(context, 'Please select a station to update');
        return;
      }

      // Create change request first (without images)
      final data = <String, dynamic>{
        'type': _type,
        if (_type == 'UPDATE_STATION' && _selectedStationId != null)
          'stationId': _selectedStationId,
        'stationData': stationData,
      };

      if (mounted) {
        AppToast.showInfo(context, 'Creating station proposal...');
      }

      final response = await repository.createChangeRequest(data);
      final changeRequestId = response['id'] as String;

      if (mounted) {
        AppToast.showSuccess(context, 'Station proposal created successfully');
      }

      if (mounted) {
        ref.invalidate(changeRequestListProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to create station proposal: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class ServiceData {
  String type;
  List<ChargingPortData> chargingPorts;

  ServiceData({
    required this.type,
    required this.chargingPorts,
  });
}

class ChargingPortData {
  String powerType;
  double? powerKw;
  int count;

  ChargingPortData({
    required this.powerType,
    this.powerKw,
    required this.count,
  });
}

