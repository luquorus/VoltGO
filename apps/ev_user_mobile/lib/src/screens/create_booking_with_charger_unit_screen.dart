import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../repositories/station_repository.dart';
import '../repositories/booking_repository.dart';
import '../providers/station_providers.dart';
import '../providers/booking_providers.dart';

/// Create Booking Screen with Charger Unit Selection
class CreateBookingWithChargerUnitScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String? stationName;

  const CreateBookingWithChargerUnitScreen({
    super.key,
    required this.stationId,
    this.stationName,
  });

  @override
  ConsumerState<CreateBookingWithChargerUnitScreen> createState() => _CreateBookingWithChargerUnitScreenState();
}

class _CreateBookingWithChargerUnitScreenState extends ConsumerState<CreateBookingWithChargerUnitScreen> {
  DateTime? _selectedDate;
  String? _selectedChargerUnitId;
  DateTime? _selectedStartTime;
  DateTime? _selectedEndTime;
  bool _isLoading = false;
  bool _isLoadingChargerUnits = false;
  bool _isLoadingAvailability = false;

  List<Map<String, dynamic>> _chargerUnits = [];
  Map<String, dynamic>? _availability;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChargerUnits();
  }

  Future<void> _loadChargerUnits() async {
    setState(() {
      _isLoadingChargerUnits = true;
      _error = null;
    });

    try {
      final repository = ref.read(stationRepositoryProvider);
      final units = await repository.getChargerUnits(widget.stationId);
      setState(() {
        _chargerUnits = units;
        _isLoadingChargerUnits = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingChargerUnits = false;
      });
    }
  }

  Future<void> _loadAvailability() async {
    if (_selectedDate == null || _selectedChargerUnitId == null) return;

    setState(() {
      _isLoadingAvailability = true;
      _error = null;
    });

    try {
      final repository = ref.read(stationRepositoryProvider);
      final availability = await repository.getAvailability(
        stationId: widget.stationId,
        date: _selectedDate!,
        slotMinutes: 30,
      );
      setState(() {
        _availability = availability;
        _isLoadingAvailability = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingAvailability = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedStartTime = null;
        _selectedEndTime = null;
      });
      await _loadAvailability();
    }
  }

  Future<void> _createBooking() async {
    if (_selectedChargerUnitId == null || _selectedStartTime == null || _selectedEndTime == null) {
      AppToast.showError(context, 'Vui lòng chọn cổng sạc và khung giờ');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(bookingRepositoryProvider);
      final booking = await repository.createBooking(
        stationId: widget.stationId,
        chargerUnitId: _selectedChargerUnitId!,
        startTime: _selectedStartTime!,
        endTime: _selectedEndTime!,
      );

      if (mounted) {
        AppToast.showSuccess(context, 'Đã tạo booking thành công!');
        final bookingId = booking['id'] as String?;
        if (bookingId != null) {
          context.push('/bookings/$bookingId');
        } else {
          context.pop();
        }
      }
    } on ApiError catch (e) {
      if (mounted) {
        if (e.code == 'EVS-0008') {
          AppToast.showError(context, 'Khung giờ đã được đặt, vui lòng chọn khung giờ khác');
          await _loadAvailability(); // Refresh availability
        } else {
          AppToast.showError(context, 'Lỗi: ${e.message}');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Lỗi: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Đặt chỗ',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station info
            if (widget.stationName != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.locationDot,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.stationName!,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error message
            if (_error != null) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.triangleExclamation,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Step 1: Date picker
            Text(
              'Bước 1: Chọn ngày',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.calendar,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Chọn ngày',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Step 2: Charger unit selection
            Text(
              'Bước 2: Chọn cổng sạc',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingChargerUnits)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_chargerUnits.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Không có cổng sạc nào',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ..._chargerUnits.map((unit) {
                final id = unit['id'] as String? ?? '';
                final label = unit['label'] as String? ?? 'N/A';
                final powerType = unit['powerType'] as String? ?? '';
                final powerKw = unit['powerKw'] as double?;
                final pricePerSlot = unit['pricePerSlot'] as int? ?? 0;
                final status = unit['status'] as String? ?? '';
                final isSelected = _selectedChargerUnitId == id;
                final isActive = status == 'ACTIVE';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: isActive
                        ? () {
                            setState(() {
                              _selectedChargerUnitId = id;
                              _selectedStartTime = null;
                              _selectedEndTime = null;
                            });
                            _loadAvailability();
                          }
                        : null,
                    child: Card(
                      color: isSelected
                          ? theme.colorScheme.primaryContainer
                          : (isActive ? null : theme.colorScheme.surfaceContainerHighest),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.plug,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        label,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$powerType ${powerKw != null ? '${powerKw.toStringAsFixed(0)}kW' : ''}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'ACTIVE'
                                              ? Colors.green
                                              : status == 'MAINTENANCE'
                                                  ? Colors.orange
                                                  : Colors.grey,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatPrice(pricePerSlot)} VND/slot (30 phút)',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              FaIcon(
                                FontAwesomeIcons.circleCheck,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // Step 3: Slot picker (only show if date and charger unit selected)
            if (_selectedDate != null && _selectedChargerUnitId != null) ...[
              Text(
                'Bước 3: Chọn khung giờ',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_isLoadingAvailability)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_availability != null)
                _buildSlotPicker(context, theme)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Không có dữ liệu availability',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Price preview (invoice)
            if (_selectedChargerUnitId != null && _selectedStartTime != null && _selectedEndTime != null)
              _buildPricePreview(context, theme),

            const SizedBox(height: 24),

            // Submit button
            PrimaryButton(
              label: 'Giữ chỗ 10 phút',
              onPressed: (_selectedChargerUnitId != null &&
                      _selectedStartTime != null &&
                      _selectedEndTime != null &&
                      !_isLoading)
                  ? _createBooking
                  : null,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotPicker(BuildContext context, ThemeData theme) {
    if (_availability == null) return const SizedBox.shrink();

    final availability = _availability!;
    final slotTimes = (availability['slotTimes'] as List<dynamic>?)
            ?.map((e) => DateTime.parse(e as String).toLocal())
            .toList() ??
        [];
    final chargerUnitAvailability = (availability['availability'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    // Find the selected charger unit's availability
    final selectedUnitAvailability = chargerUnitAvailability.firstWhere(
      (item) => (item['chargerUnit'] as Map<String, dynamic>?)?['id'] == _selectedChargerUnitId,
      orElse: () => {},
    );

    final slots = (selectedUnitAvailability['slots'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn khung giờ (30 phút/slot)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.asMap().entries.map((entry) {
                final index = entry.key;
                final slot = entry.value;
                final startTime = DateTime.parse(slot['startTime'] as String).toLocal();
                final endTime = DateTime.parse(slot['endTime'] as String).toLocal();
                final status = slot['status'] as String? ?? 'AVAILABLE';
                
                // Validate: slot must be at least 30 minutes in the future
                final now = DateTime.now();
                final minStartTime = now.add(const Duration(minutes: 30));
                final isInFuture = startTime.isAfter(minStartTime) || startTime.isAtSameMomentAs(minStartTime);
                final isAvailable = status == 'AVAILABLE' && isInFuture;
                
                final isSelected = _selectedStartTime != null &&
                    _selectedEndTime != null &&
                    _selectedStartTime!.isAtSameMomentAs(startTime) &&
                    _selectedEndTime!.isAtSameMomentAs(endTime);

                return InkWell(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            _selectedStartTime = startTime;
                            _selectedEndTime = endTime;
                          });
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : isAvailable
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isAvailable
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : isAvailable
                                    ? theme.colorScheme.onPrimaryContainer.withOpacity(0.7)
                                    : theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildPricePreview(BuildContext context, ThemeData theme) {
    // Find selected charger unit
    final selectedUnit = _chargerUnits.firstWhere(
      (unit) => unit['id'] == _selectedChargerUnitId,
      orElse: () => {},
    );
    
    if (selectedUnit.isEmpty) return const SizedBox.shrink();
    
    final pricePerSlot = selectedUnit['pricePerSlot'] as int? ?? 0;
    final label = selectedUnit['label'] as String? ?? 'N/A';
    
    // Calculate duration and slot count
    if (_selectedStartTime == null || _selectedEndTime == null) {
      return const SizedBox.shrink();
    }
    
    final duration = _selectedEndTime!.difference(_selectedStartTime!);
    final durationMinutes = duration.inMinutes;
    final slotCount = (durationMinutes + 29) ~/ 30; // Round up to nearest 30 minutes
    final totalAmount = pricePerSlot * slotCount;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin thanh toán',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPriceRow(theme, 'Cổng sạc', label),
            const SizedBox(height: 8),
            _buildPriceRow(theme, 'Giá/slot (30 phút)', '${_formatPrice(pricePerSlot)} VND'),
            const SizedBox(height: 8),
            _buildPriceRow(theme, 'Số slot', '$slotCount slot'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng tiền',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatPrice(totalAmount)} VND',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(ThemeData theme, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

