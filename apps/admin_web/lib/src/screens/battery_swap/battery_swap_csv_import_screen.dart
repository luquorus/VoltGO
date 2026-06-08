import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/battery_swap_station_providers.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';

/// CSV Import Screen for Battery Swap Stations
class BatterySwapCsvImportScreen extends ConsumerStatefulWidget {
  const BatterySwapCsvImportScreen({super.key});

  @override
  ConsumerState<BatterySwapCsvImportScreen> createState() =>
      _BatterySwapCsvImportScreenState();
}

class _BatterySwapCsvImportScreenState
    extends ConsumerState<BatterySwapCsvImportScreen> {
  FilePickerResult? _pickedFile;
  bool _isUploading = false;
  Map<String, dynamic>? _importResult;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.bytes == null && file.xFile != null) {
          try {
            final bytes = await file.xFile.readAsBytes();
            setState(() {
              _pickedFile = result;
              _importResult = null;
            });
          } catch (_) {
            _showErrorDialog(
              'Cannot read file',
              'The browser could not read the selected file. '
              'Please try again or use a different browser.',
            );
          }
        } else {
          setState(() {
            _pickedFile = result;
            _importResult = null;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Error selecting file', e.toString());
    }
  }

  Future<void> _uploadFile() async {
    // Guard 1: no file picked
    if (_pickedFile == null || _pickedFile!.files.isEmpty) {
      _showErrorDialog(
        'No file selected',
        'Please click "Choose CSV File" to select a CSV file before importing.',
      );
      return;
    }

    final file = _pickedFile!.files.single;

    // Guard 2: no bytes available
    if (file.bytes == null) {
      _showErrorDialog(
        'Cannot read file',
        'The selected file could not be read. '
        'Please re-select the file and try again.',
      );
      return;
    }

    // Guard 3: already uploading
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _importResult = null;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      final dio = factory.client;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await dio.post(
        '/api/admin/battery-swap/stations/import-csv',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.data == null) {
        throw Exception('No data received from server');
      }

      setState(() {
        _importResult = response.data as Map<String, dynamic>;
        _isUploading = false;
      });

      final successCount = _importResult!['successCount'] as int? ?? 0;
      final failureCount = _importResult!['failureCount'] as int? ?? 0;
      final totalRows = _importResult!['totalRows'] as int? ?? 0;

      if (successCount > 0) {
        ref.invalidate(
            batterySwapStationsProvider((page: 0, size: 20, search: null)));
      }

      if (totalRows == 0) {
        _showErrorDialog(
          'Invalid CSV',
          'The CSV file has no data rows. '
          'Please check the file format matches the required columns.',
        );
      } else if (failureCount == totalRows) {
        final errorMsg = _importResult!['results'] != null
            ? (_importResult!['results'] as List)
                .take(3)
                .map((r) => r['errorMessage'] ?? 'Unknown error')
                .join('\n')
            : 'All $failureCount rows failed. Check column headers.';
        _showErrorDialog('Import failed', errorMsg);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      String errorMessage = 'An unexpected error occurred.';
      if (e is DioException && e.response != null) {
        final errorData = e.response!.data;
        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['message'] as String? ??
              errorData['details']?.toString() ??
              'Server error (${e.response!.statusCode})';
        } else if (errorData is String && errorData.isNotEmpty) {
          errorMessage = errorData;
        } else {
          errorMessage = 'Server error (${e.response!.statusCode}). Please try again.';
        }
      } else {
        errorMessage = e.toString();
      }
      _showErrorDialog('Import error', errorMessage);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Import Battery Swap Stations from CSV',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CSV Format Instructions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CSV file should have the following columns (header row required):',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'name, address, latitude, longitude, totalBatteries, avgChargePowerKw, operatingHours, parkingFee, note',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• name: Station name (required)\n'
                      '• address: Full address (required)\n'
                      '• latitude: GPS latitude -90 to 90 (required)\n'
                      '• longitude: GPS longitude -180 to 180 (required)\n'
                      '• totalBatteries: Number of batteries, e.g. 20 (required)\n'
                      '• avgChargePowerKw: Charging power in kW, e.g. 3.5 (required)\n'
                      '• operatingHours: Format "06:00-22:00" (required)\n'
                      '• parkingFee: Numeric, e.g. 5000 (optional)\n'
                      '• note: Any notes (optional)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // File Picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select CSV File',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickFile,
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              _pickedFile?.files.single.name ?? 'Choose CSV File',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: (_pickedFile != null && !_isUploading)
                              ? _uploadFile
                              : null,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isUploading ? 'Importing...' : 'Import'),
                        ),
                      ],
                    ),
                    if (_pickedFile != null && _pickedFile!.files.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile!.files.single.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_pickedFile!.files.single.size} bytes',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  _pickedFile = null;
                                  _importResult = null;
                                });
                              },
                              tooltip: 'Remove file',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Import Results
            if (_importResult != null) ...[
              const SizedBox(height: 24),
              _buildImportResults(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImportResults(ThemeData theme) {
    final results = _importResult!['results'] as List<dynamic>? ?? [];
    final successCount = _importResult!['successCount'] as int? ?? 0;
    final failureCount = _importResult!['failureCount'] as int? ?? 0;
    final totalRows = _importResult!['totalRows'] as int? ?? 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (failureCount == 0 && successCount > 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Import completed successfully';
    } else if (successCount > 0 && failureCount > 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Partial import succeeded';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Import failed';
    }

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: statusColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: $totalRows | Succeeded: $successCount | Failed: $failureCount',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (failureCount > 0)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pickedFile = null;
                        _importResult = null;
                      });
                    },
                    child: const Text('Try Again'),
                  ),
              ],
            ),
          ),
          // Results Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(theme, 'Total', totalRows, Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          _buildStatCard(theme, 'Succeeded', successCount, Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(theme, 'Failed', failureCount, Colors.red),
                    ),
                  ],
                ),
                if (results.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.list, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Per-station details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 400,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index] as Map<String, dynamic>;
                        final isSuccess = result['success'] as bool? ?? false;
                        final rowNumber = result['rowNumber'] as int? ?? 0;
                        final stationName =
                            result['stationName'] as String? ?? 'Unknown';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          color: isSuccess
                              ? Colors.green.withOpacity(0.05)
                              : Colors.red.withOpacity(0.05),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSuccess
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSuccess ? Icons.check_circle : Icons.error,
                                color: isSuccess ? Colors.green : Colors.red,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              'Row $rowNumber: $stationName',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: isSuccess
                                  ? Row(
                                      children: [
                                        Icon(Icons.tag,
                                            size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ID: ${result['stationId']}',
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[700],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                size: 16,
                                                color: Colors.red[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Error:',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          result['errorMessage'] as String? ??
                                              'Unknown error',
                                          style:
                                              theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            trailing: isSuccess
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.close, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
