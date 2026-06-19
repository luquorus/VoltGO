import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';

/// Station Search Dropdown Widget
///
/// A searchable dropdown that allows users to search and select a station by name.
/// Only displays PUBLISHED stations.
/// Supports both charging stations and battery swap stations via [stationKind].
class StationSearchDropdown extends ConsumerStatefulWidget {
  final ValueChanged<String?> onStationSelected; // stationId
  final String? initialStationId;
  final bool enabled;
  final String? Function(String?)? validator;
  /// 'CHARGING' or 'BATTERY_SWAP'. Determines which API endpoint is used for search.
  final String stationKind;
  final double defaultLat;
  final double defaultLng;

  const StationSearchDropdown({
    super.key,
    required this.onStationSelected,
    this.initialStationId,
    this.enabled = true,
    this.validator,
    this.stationKind = 'CHARGING',
    this.defaultLat = 0,
    this.defaultLng = 0,
  });

  @override
  ConsumerState<StationSearchDropdown> createState() => _StationSearchDropdownState();
}

class _StationSearchDropdownState extends ConsumerState<StationSearchDropdown> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearching = false;
  bool _showDropdown = false;
  List<StationOption> _stations = [];
  String? _selectedStationId;
  String? _selectedStationName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedStationId = widget.initialStationId;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant StationSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationKind != widget.stationKind) {
      // Station kind changed (CHARGING <-> BATTERY_SWAP). Clear any prior
      // selection and results so the next search uses the new branch and the
      // parent form is notified that no station is currently selected.
      setState(() {
        _selectedStationId = null;
        _selectedStationName = null;
        _stations = [];
        _error = null;
        _isSearching = false;
        _searchController.clear();
        _showDropdown = false;
      });
      widget.onStationSelected(null);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay to allow tap on dropdown item
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showDropdown = false;
          });
        }
      });
    } else {
      setState(() {
        _showDropdown = true;
      });
    }
  }

  Future<void> _searchStations(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _stations = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }

    if (query.trim().length < 2) {
      setState(() {
        _stations = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      List<StationOption> stations;

      if (widget.stationKind == 'BATTERY_SWAP') {
        final response = await factory.ev.searchBatterySwapStationsByName(
          name: query.trim(),
          page: 0,
          size: 20,
        );
        final content = response['content'] as List<dynamic>? ?? [];
        stations = content.map((item) {
          final station = item as Map<String, dynamic>;
          return StationOption(
            id: station['id'] as String? ?? station['stationId'] as String? ?? '',
            name: station['name'] as String? ?? 'Unknown',
            address: station['address'] as String?,
          );
        }).toList();
      } else {
        final response = await factory.ev.searchStationsByName(
          name: query.trim(),
          page: 0,
          size: 20,
        );
        final content = response['content'] as List<dynamic>? ?? [];
        stations = content.map((item) {
          final station = item as Map<String, dynamic>;
          return StationOption(
            id: station['stationId'] as String? ?? '',
            name: station['name'] as String? ?? 'Unknown',
            address: station['address'] as String?,
          );
        }).toList();
      }

      if (mounted) {
        setState(() {
          _stations = stations;
          _isSearching = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stations = [];
          _isSearching = false;
          _error = 'Station search failed: ${formatApiError(e)}';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == value) {
        _searchStations(value);
      }
    });
  }

  void _selectStation(StationOption station) {
    setState(() {
      _selectedStationId = station.id;
      _selectedStationName = station.name;
      _searchController.text = station.name;
      _showDropdown = false;
      _stations = [];
    });
    _focusNode.unfocus();
    widget.onStationSelected(station.id);
  }

  void _clearSelection() {
    setState(() {
      _selectedStationId = null;
      _selectedStationName = null;
      _searchController.clear();
      _stations = [];
    });
    widget.onStationSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Select Station *',
            hintText: 'Type station name to search...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: _selectedStationId != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: widget.enabled ? _clearSelection : null,
                    tooltip: 'Clear selection',
                  )
                : _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
          ),
          onChanged: widget.enabled ? _onSearchChanged : null,
          validator: widget.validator,
        ),
        // Dropdown overlay
        if (_showDropdown && _stations.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _stations.length,
              itemBuilder: (context, index) {
                final station = _stations[index];
                return InkWell(
                  onTap: () => _selectStation(station),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (station.address != null &&
                            station.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            station.address!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        // Error message
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        // Empty state message
        if (_showDropdown &&
            !_isSearching &&
            _stations.isEmpty &&
            _searchController.text.trim().length >= 2) ...[
          const SizedBox(height: 4),
          Text(
            'No stations found',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
        // Selected station info
        if (_selectedStationId != null && _selectedStationName != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected: $_selectedStationName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Station option model
class StationOption {
  final String id;
  final String name;
  final String? address;

  StationOption({
    required this.id,
    required this.name,
    this.address,
  });
}

