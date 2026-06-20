import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Filter state holding the selected filter values.
class HomeMapFilterState {
  final double radiusKm;
  final double? minPowerKw;
  final bool? hasAC;

  const HomeMapFilterState({
    this.radiusKm = 5.0,
    this.minPowerKw,
    this.hasAC,
  });

  HomeMapFilterState copyWith({
    double? radiusKm,
    double? minPowerKw,
    bool? hasAC,
    bool clearMinPowerKw = false,
    bool clearHasAC = false,
  }) {
    return HomeMapFilterState(
      radiusKm: radiusKm ?? this.radiusKm,
      minPowerKw: clearMinPowerKw ? null : (minPowerKw ?? this.minPowerKw),
      hasAC: clearHasAC ? null : (hasAC ?? this.hasAC),
    );
  }

  bool get hasActiveFilters =>
      radiusKm != 5.0 || minPowerKw != null || hasAC != null;

  List<String> get activeFilterChips {
    final chips = <String>[];
    chips.add('${radiusKm.toStringAsFixed(0)} km');
    if (minPowerKw != null) {
      chips.add('${minPowerKw!.toStringAsFixed(0)} kW+');
    }
    if (hasAC == true) chips.add('AC');
    if (hasAC == false) chips.add('DC Fast');
    return chips;
  }
}

/// Mobile-friendly filter bottom sheet replacing the old AlertDialog.
class FilterBottomSheet extends StatefulWidget {
  final HomeMapFilterState initialFilter;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late double _radiusKm;
  double? _minPowerKw;
  bool? _hasAC;

  // Convenience setters for chip-based selection
  void _setMinPowerKw(double? value) {
    setState(() {
      if (value == null || _minPowerKw == value) {
        _minPowerKw = null;
      } else {
        _minPowerKw = value;
      }
    });
  }

  void _setHasAC(bool? value) {
    setState(() {
      if (value == null || _hasAC == value) {
        _hasAC = null;
      } else {
        _hasAC = value;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initialFilter.radiusKm;
    _minPowerKw = widget.initialFilter.minPowerKw;
    _hasAC = widget.initialFilter.hasAC;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.filter,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Filters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _radiusKm = 5.0;
                        _minPowerKw = null;
                        _hasAC = null;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Distance section
            _SectionTitle(title: 'Distance'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [2.0, 5.0, 10.0, 20.0].map((km) {
                  final isSelected = _radiusKm == km;
                  return ChoiceChip(
                    label: Text('${km.toStringAsFixed(0)} km'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _radiusKm = km);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_radiusKm.toStringAsFixed(0)} km',
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${_radiusKm.toStringAsFixed(0)} km',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Minimum power section
            _SectionTitle(title: 'Minimum power'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (null, 'Any'),
                  (22.0, '22 kW+'),
                  (50.0, '50 kW+'),
                  (100.0, '100 kW+'),
                ].map((option) {
                  final isSelected = _minPowerKw == option.$1;
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _setMinPowerKw(option.$1);
                      } else {
                        setState(() => _minPowerKw = null);
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Charger type section
            _SectionTitle(title: 'Charger type'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (null, 'Any'),
                  (true, 'AC'),
                  (false, 'DC Fast'),
                ].map((option) {
                  final isSelected = _hasAC == option.$1;
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _setHasAC(option.$1);
                      } else {
                        setState(() => _hasAC = null);
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context, HomeMapFilterState(
                          radiusKm: _radiusKm,
                          minPowerKw: _minPowerKw,
                          hasAC: _hasAC,
                        ));
                      },
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
      ),
    );
  }
}
