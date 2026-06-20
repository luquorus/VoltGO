import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/change_request_providers.dart';
import '../providers/battery_swap_change_request_providers.dart';
import '../providers/loyalty_providers.dart';
import '../repositories/change_request_repository.dart';
import '../repositories/battery_swap_change_request_repository.dart';
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

  // Request type: CREATE_STATION or UPDATE_STATION
  String? _type;
  // Selected station ID for UPDATE_STATION
  String? _selectedStationId;

  // Primary station kind — determines which form to show
  // 'CHARGING' → charging station form
  // 'BATTERY_SWAP' → battery swap station form
  String _stationKind = 'CHARGING';

  // Shared station name/address/location fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  String? _visibility;
  String? _publicStatus;
  // Parking: PAID / FREE / STREET_PARKING / UNKNOWN
  String? _parking;

  // Charging station services
  List<ServiceData> _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];

  // Battery swap specific fields
  final _totalBatteriesController = TextEditingController(text: '20');
  final _avgChargePowerKwController = TextEditingController(text: '35.0');

  // Default location for station search
  double _defaultLat = 0;
  double _defaultLng = 0;

  bool _isSubmitting = false;
  bool _isGettingLocation = false;
  bool _isLoadingStation = false;

  @override
  void initState() {
    super.initState();
    _initDefaultLocation();
  }

  Future<void> _initDefaultLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _defaultLat = position.latitude;
            _defaultLng = position.longitude;
          });
        }
      }
    } catch (_) {
      // Silently fail — dropdown search will use 0,0 which is fine
    }
  }
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _operatingHoursController.dispose();
    _totalBatteriesController.dispose();
    _avgChargePowerKwController.dispose();
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
              // Station kind selector (top level)
              _buildStationKindSelector(theme),
              const SizedBox(height: 24),

              // Request type selector
              _buildTypeSelector(theme),
              const SizedBox(height: 24),

              // Station kind-specific form
              if (_stationKind == 'CHARGING')
                ..._buildChargingStationForm(theme)
              else
                ..._buildBatterySwapStationForm(theme),

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

  /// Builds the station kind selector card (top of form).
  Widget _buildStationKindSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Type *',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the type of station you want to create or update.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Charging station'),
                    value: 'CHARGING',
                    groupValue: _stationKind,
                    onChanged: _isSubmitting ? null : (value) {
                      if (value == null) return;
                      setState(() {
                        _stationKind = value;
                        _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Battery swap station'),
                    value: 'BATTERY_SWAP',
                    groupValue: _stationKind,
                    onChanged: _isSubmitting ? null : (value) {
                      if (value == null) return;
                      setState(() {
                        _stationKind = value;
                        _services = [];
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

  /// Builds the charging station form sections.
  List<Widget> _buildChargingStationForm(ThemeData theme) {
    return [
      if (_type == 'UPDATE_STATION') ...[
        StationSearchDropdown(
          onStationSelected: (stationId) {
            if (stationId != null) {
              _loadStationData(stationId);
            } else {
              setState(() {
                _selectedStationId = null;
                _clearChargingForm();
              });
            }
          },
          initialStationId: _selectedStationId,
          enabled: !_isSubmitting && !_isLoadingStation,
          stationKind: 'CHARGING',
          defaultLat: _defaultLat,
          defaultLng: _defaultLng,
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

      _buildChargingStationFields(theme),
    ];
  }

  /// Shared station info fields for charging station.
  Widget _buildChargingStationFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (value == null || value.isEmpty) return 'Name is required';
            if (value.length < 3) return 'Name must be at least 3 characters';
            if (value.length > 255) return 'Name must be at most 255 characters';
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Latitude is required';
                  final lat = double.tryParse(value.trim());
                  if (lat == null) return 'Invalid latitude';
                  if (lat < -90 || lat > 90) return 'Latitude must be between -90 and 90';
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Longitude is required';
                  final lng = double.tryParse(value.trim());
                  if (lng == null) return 'Invalid longitude';
                  if (lng < -180 || lng > 180) return 'Longitude must be between -180 and 180';
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

        _buildDropdown(theme, 'Visibility', _visibility, ['PUBLIC', 'PRIVATE', 'RESTRICTED'],
            (v) => setState(() => _visibility = v)),
        const SizedBox(height: 16),

        _buildDropdown(theme, 'Public Status', _publicStatus, ['ACTIVE', 'INACTIVE', 'MAINTENANCE'],
            (v) => setState(() => _publicStatus = v)),
        const SizedBox(height: 16),

        _buildDropdown(theme, 'Parking', _parking, ['PAID', 'FREE', 'STREET_PARKING', 'UNKNOWN'],
            (v) => setState(() => _parking = v)),
        const SizedBox(height: 24),

        Text(
          'Charging ports',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ..._services.asMap().entries.map((entry) {
          return _buildServiceEditor(theme, entry.key, entry.value);
        }),
      ],
    );
  }

  /// Builds the battery swap station form sections.
  List<Widget> _buildBatterySwapStationForm(ThemeData theme) {
    return [
      if (_type == 'UPDATE_STATION') ...[
        StationSearchDropdown(
          onStationSelected: (stationId) {
            if (stationId != null) {
              _loadBatterySwapStationData(stationId);
            } else {
              setState(() {
                _selectedStationId = null;
                _clearBatterySwapForm();
              });
            }
          },
          initialStationId: _selectedStationId,
          enabled: !_isSubmitting && !_isLoadingStation,
          stationKind: 'BATTERY_SWAP',
          defaultLat: _defaultLat,
          defaultLng: _defaultLng,
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

      _buildBatterySwapFields(theme),
    ];
  }

  /// Battery swap station form fields.
  /// Note: CreateBatterySwapCRDTO only supports totalBatteries, avgChargePowerKw,
  /// operatingHours, parkingFee (optional), note (optional), pileTemplates (optional).
  /// Fields like name/address/location are managed by the parent StationEntity separately.
  Widget _buildBatterySwapFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Battery Swap Configuration',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        AppTextField(
          label: 'Operating Hours *',
          controller: _operatingHoursController,
          enabled: !_isSubmitting,
          hint: 'e.g., 06:00-22:00',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Operating hours is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _totalBatteriesController,
          decoration: InputDecoration(
            labelText: 'Total batteries *',
            hintText: 'Number of batteries in the station',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isSubmitting,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Total batteries is required';
            }
            final n = int.tryParse(value.trim());
            if (n == null || n <= 0) {
              return 'Must be greater than 0';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _avgChargePowerKwController,
          decoration: InputDecoration(
            labelText: 'Avg charge power (kW) *',
            hintText: 'Average charging power per battery',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          enabled: !_isSubmitting,
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

        _buildBatterySwapConfig(theme),
      ],
    );
  }

  Widget _buildBatterySwapConfig(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _totalBatteriesController,
              decoration: InputDecoration(
                labelText: 'Total batteries *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _avgChargePowerKwController,
              decoration: InputDecoration(
                labelText: 'Avg charge power (kW) *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              enabled: !_isSubmitting,
            ),
          ],
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
                        _clearAllForms();
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
            if (service.type == 'CHARGING') ...[
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
        AppToast.showError(context, 'Could not get location: ${formatApiError(e)}');
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
        _visibility = stationData['visibility'] as String?;
        _publicStatus = stationData['publicStatus'] as String?;
        _parking = stationData['parking'] as String?;

        // Load services (preferred) or legacy ports list
        final servicesRaw = stationData['services'] as List<dynamic>?;
        final List<ServiceData> loaded = [];

        if (servicesRaw != null && servicesRaw.isNotEmpty) {
          for (final raw in servicesRaw) {
            final m = raw as Map<String, dynamic>;
            final t = (m['type'] as String?) ?? 'CHARGING';
            if (t == 'BATTERY_SWAP') {
              loaded.add(ServiceData(
                type: 'BATTERY_SWAP',
                chargingPorts: [],
                totalBatteries: (m['totalBatteries'] as num?)?.toInt() ?? 20,
                avgChargePowerKw:
                    (m['avgChargePowerKw'] as num?)?.toDouble() ?? 35.0,
              ));
            } else if (t == 'CHARGING') {
              final cList = m['chargingPorts'] as List<dynamic>? ?? [];
              final chargingPorts = cList.map((p) {
                final pd = p as Map<String, dynamic>;
                return ChargingPortData(
                  powerType: pd['powerType'] as String? ?? 'AC',
                  powerKw: pd['powerKw'] != null
                      ? (pd['powerKw'] as num).toDouble()
                      : null,
                  count: pd['count'] as int? ?? 1,
                );
              }).toList();
              loaded.add(ServiceData(
                type: 'CHARGING',
                chargingPorts: chargingPorts,
              ));
            }
          }
        }

        final ports = stationData['ports'] as List<dynamic>? ?? [];
        if (loaded.isEmpty && ports.isNotEmpty) {
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
          loaded.add(ServiceData(type: 'CHARGING', chargingPorts: chargingPorts));
        }

        final hasSwap = loaded.any((s) => s.type == 'BATTERY_SWAP');
        final hasCharging = loaded.any((s) => s.type == 'CHARGING');
        setState(() {
          if (hasSwap && !hasCharging) {
            _stationKind = 'BATTERY_SWAP';
            _services = loaded
                .where((s) => s.type == 'BATTERY_SWAP')
                .toList();
            if (_services.isEmpty) {
              _services = [
                ServiceData(
                  type: 'BATTERY_SWAP',
                  chargingPorts: [],
                  totalBatteries: 20,
                  avgChargePowerKw: 35.0,
                ),
              ];
            }
          } else {
            _stationKind = 'CHARGING';
            _services = loaded
                .where((s) => s.type == 'CHARGING')
                .toList();
            if (_services.isEmpty) {
              _services = [
                ServiceData(type: 'CHARGING', chargingPorts: []),
              ];
            }
          }
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
        AppToast.showError(context, 'Failed to load station data: ${formatApiError(e)}');
      }
    }
  }

  void _clearAllForms() {
    _nameController.clear();
    _addressController.clear();
    _latController.clear();
    _lngController.clear();
    _operatingHoursController.clear();
    _visibility = null;
    _publicStatus = null;
    _parking = null;
    _totalBatteriesController.text = '20';
    _avgChargePowerKwController.text = '35.0';
    setState(() {
      _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];
    });
  }

  void _clearChargingForm() {
    _nameController.clear();
    _addressController.clear();
    _latController.clear();
    _lngController.clear();
    _operatingHoursController.clear();
    _visibility = null;
    _publicStatus = null;
    _parking = null;
    setState(() {
      _services = [ServiceData(type: 'CHARGING', chargingPorts: [])];
    });
  }

  void _clearBatterySwapForm() {
    _operatingHoursController.clear();
    _totalBatteriesController.text = '20';
    _avgChargePowerKwController.text = '35.0';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_type == null) {
      AppToast.showError(context, 'Please select request type');
      return;
    }

    // Charging station requires name and location
    if (_stationKind == 'CHARGING') {
      if (_nameController.text.trim().isEmpty) {
        AppToast.showError(context, 'Station name is required');
        return;
      }
      if (_latController.text.trim().isEmpty || _lngController.text.trim().isEmpty) {
        AppToast.showError(context, 'Location is required');
        return;
      }
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat == null || lat < -90 || lat > 90) {
        AppToast.showError(context, 'Invalid latitude');
        return;
      }
      if (lng == null || lng < -180 || lng > 180) {
        AppToast.showError(context, 'Invalid longitude');
        return;
      }
    }
    // Battery swap validation is handled by Form validators in _buildBatterySwapFields

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_stationKind == 'CHARGING') {
        await _submitChargingStation();
      } else {
        await _submitBatterySwapStation();
      }

      if (mounted) {
        AppToast.showSuccess(context, 'Station proposal created successfully! You earned +10 points');
        ref.invalidate(changeRequestListProvider);
        ref.invalidate(loyaltyProfileProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to create station edit proposal: ${formatApiError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitChargingStation() async {
    // Validate charging ports
    for (int i = 0; i < _services.length; i++) {
      final service = _services[i];
      if (service.chargingPorts.isEmpty) {
        throw Exception('Service ${i + 1}: At least one charging port is required');
      }
      for (int j = 0; j < service.chargingPorts.length; j++) {
        final port = service.chargingPorts[j];
        if (port.count < 1) {
          throw Exception('Service ${i + 1}, Port ${j + 1}: Count must be >= 1');
        }
        if (port.powerType == 'DC' && (port.powerKw == null || port.powerKw! <= 0)) {
          throw Exception('Service ${i + 1}, Port ${j + 1}: Power (kW) is required and must be > 0 for DC');
        }
      }
    }

    final repository = ref.read(changeRequestRepositoryProvider);

    final stationData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : 'Address not provided',
      'location': {
        'lat': double.parse(_latController.text.trim()),
        'lng': double.parse(_lngController.text.trim()),
      },
      'visibility': _visibility ?? 'PUBLIC',
      'publicStatus': _publicStatus ?? 'ACTIVE',
      'parking': _parking ?? 'UNKNOWN',
      'services': _services.map((service) {
        final serviceData = <String, dynamic>{
          'type': service.type,
        };
        if (service.chargingPorts.isNotEmpty) {
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
      }).toList(),
    };

    if (_operatingHoursController.text.trim().isNotEmpty) {
      stationData['operatingHours'] = _operatingHoursController.text.trim();
    }

    final data = <String, dynamic>{
      'type': _type,
      if (_type == 'UPDATE_STATION' && _selectedStationId != null)
        'stationId': _selectedStationId,
      'stationData': stationData,
    };

    await repository.createChangeRequest(data);
  }

  Future<void> _submitBatterySwapStation() async {
    final totalBatteries = int.tryParse(_totalBatteriesController.text.trim());
    final avgPowerKw = double.tryParse(_avgChargePowerKwController.text.trim());

    if (totalBatteries == null || totalBatteries <= 0) {
      throw Exception('Total batteries must be greater than 0');
    }
    if (avgPowerKw == null || avgPowerKw <= 0) {
      throw Exception('Average charge power (kW) must be greater than 0');
    }
    if (_operatingHoursController.text.trim().isEmpty) {
      throw Exception('Operating hours is required for battery swap stations');
    }

    final repository = ref.read(batterySwapChangeRequestRepositoryProvider);

    // Fields in CreateBatterySwapCRDTO: type, stationId, totalBatteries,
    // avgChargePowerKw, operatingHours, parkingFee (optional), note (optional),
    // pileTemplates (optional).
    final data = <String, dynamic>{
      'type': _type == 'CREATE_STATION'
          ? 'CREATE_BATTERY_SWAP_STATION'
          : 'UPDATE_BATTERY_SWAP_STATION',
      if (_type == 'UPDATE_STATION' && _selectedStationId != null)
        'stationId': _selectedStationId,
      'totalBatteries': totalBatteries,
      'avgChargePowerKw': avgPowerKw,
      'operatingHours': _operatingHoursController.text.trim(),
      'pileTemplates': [],
    };

    await repository.createChangeRequest(data);
  }

  Future<void> _loadBatterySwapStationData(String stationId) async {
    setState(() {
      _isLoadingStation = true;
      _selectedStationId = stationId;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      final stationData = await factory.ev.getBatterySwapStationDetail(stationId);

      if (mounted) {
        _nameController.text = stationData['name'] as String? ?? '';

        final lat = stationData['lat'] as double?;
        final lng = stationData['lng'] as double?;
        if (lat != null) _latController.text = lat.toStringAsFixed(6);
        if (lng != null) _lngController.text = lng.toStringAsFixed(6);

        _operatingHoursController.text = stationData['operatingHours'] as String? ?? '';
        final avgPowerKw = stationData['avgChargePowerKw'];
        if (avgPowerKw != null) {
          _avgChargePowerKwController.text = (avgPowerKw as num).toDouble().toStringAsFixed(1);
        }

        if (mounted) {
          setState(() {
            _isLoadingStation = false;
          });
          AppToast.showSuccess(context, 'Station data loaded successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStation = false;
          _selectedStationId = null;
        });
        AppToast.showError(context, 'Failed to load station data: ${formatApiError(e)}');
      }
    }
  }
}

class ServiceData {
  String type;
  List<ChargingPortData> chargingPorts;
  int? totalBatteries;
  double? avgChargePowerKw;

  ServiceData({
    required this.type,
    required this.chargingPorts,
    this.totalBatteries,
    this.avgChargePowerKw,
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

