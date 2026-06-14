import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_station.dart';
import '../models/battery_swap_station.dart';
import '../models/pagination_response.dart';
import '../providers/station_providers.dart';
import '../providers/battery_swap_station_providers.dart';

/// Unified station types for search dropdown
enum StationType { charging, batterySwap }

/// Result item for station search
class StationSearchItem {
  final String id;
  final String? name;
  final String? address;
  final StationType type;

  StationSearchItem({
    required this.id,
    this.name,
    this.address,
    required this.type,
  });

  String get displayName => name ?? id;
}

/// Combined search state
class StationSearchState {
  final List<StationSearchItem> items;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;
  final String? currentQuery;

  const StationSearchState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = false,
    this.currentPage = 0,
    this.currentQuery,
  });

  StationSearchState copyWith({
    List<StationSearchItem>? items,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
    String? currentQuery,
  }) {
    return StationSearchState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }
}

/// Provider for station search (notified by the widget's controller)
final stationSearchProvider =
    StateNotifierProvider.family<StationSearchNotifier, StationSearchState, StationType>(
  (ref, type) => StationSearchNotifier(ref, type),
);

class StationSearchNotifier extends StateNotifier<StationSearchState> {
  final Ref _ref;
  final StationType _type;
  Timer? _debounce;

  StationSearchNotifier(this._ref, this._type) : super(const StationSearchState());

  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(query));
  }

  void loadMore(String query) {
    if (state.isLoading || !state.hasMore) return;
    _fetch(query, append: true);
  }

  void clear() {
    _debounce?.cancel();
    state = const StationSearchState();
  }

  Future<void> _fetch(String query, {bool append = false}) async {
    final nextPage = append ? state.currentPage + 1 : 0;
    const pageSize = 20;

    if (append) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null, items: []);
    }

    try {
      List<StationSearchItem> newItems;

      if (_type == StationType.charging) {
        final factory = _ref.read(apiClientFactoryProvider);
        if (factory == null) throw Exception('API client not initialized');

        final response = await factory.admin.getStations(
          page: nextPage,
          size: pageSize,
          search: query.isEmpty ? null : query,
        );

        final pagination = PaginationResponse<AdminStation>.fromJson(
          Map<String, dynamic>.from(response),
          AdminStation.fromJson,
        );

        newItems = pagination.content.map((s) => StationSearchItem(
          id: s.stationId,
          name: s.name,
          address: s.address,
          type: StationType.charging,
        )).toList();
      } else {
        final factory = _ref.read(apiClientFactoryProvider);
        if (factory == null) throw Exception('API client not initialized');

        final response = await factory.admin.getBatterySwapStations(
          page: nextPage,
          size: pageSize,
          search: query.isEmpty ? null : query,
        );

        final content = (response['content'] as List<dynamic>?)
                ?.map((json) => BatterySwapStation.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];
        final totalElements = response['totalElements'] as int? ?? 0;

        newItems = content.map((s) => StationSearchItem(
          id: s.id,
          name: s.name,
          address: s.address,
          type: StationType.batterySwap,
        )).toList();

        state = state.copyWith(
          isLoading: false,
          items: append ? [...state.items, ...newItems] : newItems,
          hasMore: (nextPage + 1) * pageSize < totalElements,
          currentPage: nextPage,
          currentQuery: query,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        items: append ? [...state.items, ...newItems] : newItems,
        hasMore: newItems.length >= pageSize,
        currentPage: nextPage,
        currentQuery: query,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Station search dropdown with autocomplete-style search
class StationSearchDropdown extends ConsumerStatefulWidget {
  final StationType stationType;
  final String? selectedStationId;
  final String? preselectedStationName;
  final ValueChanged<StationSearchItem?> onChanged;
  final String? errorText;
  final bool enabled;
  final bool isReadOnly;

  const StationSearchDropdown({
    super.key,
    required this.stationType,
    this.selectedStationId,
    this.preselectedStationName,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<StationSearchDropdown> createState() => _StationSearchDropdownState();
}

class _StationSearchDropdownState extends ConsumerState<StationSearchDropdown> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _scrollController = ScrollController();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  StationSearchItem? _selectedItem;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);

    // Handle pre-selected station
    if (widget.preselectedStationName != null) {
      _searchController.text = widget.preselectedStationName!;
      // Only seed selection when an explicit id (UUID) is provided; never
      // fall back to the name, otherwise downstream trust calls will hit
      // `GET /api/admin/stations/<name>/trust` and fail with EVS-0002.
      if (widget.selectedStationId != null && widget.selectedStationId!.isNotEmpty) {
        _selectedItem = StationSearchItem(
          id: widget.selectedStationId!,
          name: widget.preselectedStationName,
          type: widget.stationType == StationType.charging
              ? StationType.charging
              : StationType.batterySwap,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged(_selectedItem);
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.isReadOnly) {
      _focusNode.unfocus();
      return;
    }
    if (_focusNode.hasFocus && !_isOpen) {
      _openDropdown();
    } else if (!_focusNode.hasFocus && _isOpen) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      final searchState = ref.read(stationSearchProvider(widget.stationType));
      if (!searchState.isLoading && searchState.hasMore) {
        ref.read(stationSearchProvider(widget.stationType).notifier).loadMore(
              searchState.currentQuery ?? '',
            );
      }
    }
  }

  void _openDropdown() {
    if (!widget.enabled || widget.isReadOnly) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
    ref.read(stationSearchProvider(widget.stationType).notifier).search('');
  }

  void _closeDropdown() {
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: _buildDropdownContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent() {
    final searchState = ref.watch(stationSearchProvider(widget.stationType));

    if (searchState.isLoading && searchState.items.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (searchState.error != null && searchState.items.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'Error loading stations',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (searchState.items.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'No stations found',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: searchState.items.length + (searchState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= searchState.items.length) {
          return searchState.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : const SizedBox.shrink();
        }

        final item = searchState.items[index];
        final isSelected = _selectedItem?.id == item.id;

        return InkWell(
          onTap: () => _onItemSelected(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                : null,
            child: Row(
              children: [
                Icon(
                  item.type == StationType.charging
                      ? Icons.ev_station
                      : Icons.battery_charging_full,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : null,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.address != null)
                        Text(
                          item.address!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onItemSelected(StationSearchItem item) {
    setState(() => _selectedItem = item);
    _searchController.text = item.displayName;
    _closeDropdown();
    widget.onChanged(item);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!_isOpen) {
        _openDropdown();
      } else {
        _overlayEntry?.markNeedsBuild();
      }
      ref.read(stationSearchProvider(widget.stationType).notifier).search(value);
    });
  }

  void _clearSelection() {
    setState(() => _selectedItem = null);
    _searchController.clear();
    widget.onChanged(null);
    ref.read(stationSearchProvider(widget.stationType).notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    // When read-only with pre-selected station, show as read-only TextFormField
    if (widget.isReadOnly && widget.preselectedStationName != null) {
      return TextFormField(
        controller: _searchController,
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Station Name *',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.lock, size: 18, color: Colors.grey),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
      );
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _searchController,
            focusNode: _focusNode,
            enabled: widget.enabled,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Station Name *',
              hintText: widget.stationType == StationType.charging
                  ? 'Search charging stations by name...'
                  : 'Search battery swap stations by name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _selectedItem != null && !widget.isReadOnly
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: widget.enabled ? _clearSelection : null,
                    )
                  : null,
              errorText: widget.errorText,
            ),
          ),
        ],
      ),
    );
  }
}
