import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// CSV Import Screen
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  FilePickerResult? _pickedFile;
  bool _isUploading = false;
  Map<String, dynamic>? _importResult;

  Future<void> _pickFile() async {
    try {
      // withData: true ensures bytes are available on all platforms (required for web)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // This ensures bytes are available (required for web)
      );

      if (result != null) {
        setState(() {
          _pickedFile = result;
          _importResult = null;
        });
        print('File picked successfully: ${result.files.single.name}');
        if (result.files.single.bytes != null) {
          print('File bytes available: ${result.files.single.bytes!.length} bytes');
        }
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadFile() async {
    print('_uploadFile called');
    
    if (_pickedFile == null) {
      print('No file picked');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn file CSV trước'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pickedFile!.files.isEmpty) {
      print('File list is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có file nào được chọn'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('File picked: ${_pickedFile!.files.single.name}');
    print('File size: ${_pickedFile!.files.single.size} bytes');
    print('Has bytes: ${_pickedFile!.files.single.bytes != null}');
    // Note: On web, path is unavailable - don't access it

    setState(() {
      _isUploading = true;
      _importResult = null; // Clear previous results
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('API client not initialized');
      }

      print('API factory obtained');

      // Read file bytes
      // On web: use bytes directly (path is unavailable)
      // On mobile: bytes should also be available, but can fallback to path if needed
      Uint8List fileBytes;
      String fileName = _pickedFile!.files.single.name;
      
      if (_pickedFile!.files.single.bytes != null) {
        // Use bytes directly (works on both web and mobile)
        print('Using file bytes');
        fileBytes = _pickedFile!.files.single.bytes!;
      } else {
        // Fallback: try to read from path (mobile only, path is unavailable on web)
        // This should rarely happen as file_picker usually provides bytes
        throw Exception('Cannot read file: bytes not available. Please ensure file_picker is configured to read file bytes.');
      }

      print('File bytes read: ${fileBytes.length} bytes');

      // Create multipart request
      final dio = factory.client;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });

      // Make API call with proper error handling
      print('Sending POST request to /api/admin/stations/import-csv');
      print('FormData file name: $fileName');
      print('FormData file size: ${fileBytes.length} bytes');
      
      final response = await dio.post(
        '/api/admin/stations/import-csv',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      print('Response received: ${response.statusCode}');
      print('Response data: ${response.data}');

      // Check response
      if (response.statusCode != 200) {
        throw Exception('Import failed with status: ${response.statusCode}');
      }

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

      // Refresh stations list if any were imported successfully
      if (successCount > 0) {
        // Invalidate all station providers to refresh the list
        ref.invalidate(stationsProvider((page: 0, size: 20)));
      }

      // Show detailed notification
      if (failureCount == 0 && successCount > 0) {
        // All succeeded
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Import thành công! Đã import $successCount/$totalRows trạm sạc.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (successCount > 0 && failureCount > 0) {
        // Partial success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Import một phần: $successCount/$totalRows thành công, $failureCount thất bại. Vui lòng kiểm tra chi tiết bên dưới.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (failureCount == totalRows) {
        // All failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Import thất bại! Tất cả $failureCount trạm đều không thể import. Vui lòng kiểm tra chi tiết bên dưới.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      setState(() {
        _isUploading = false;
      });

      // Log error for debugging
      print('CSV Import Error: $e');
      print('Stack trace: $stackTrace');

      String errorMessage = 'Lỗi khi upload file';
      if (e is DioException) {
        print('DioException type: ${e.type}');
        print('DioException message: ${e.message}');
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        
        if (e.response != null) {
          final errorData = e.response!.data;
          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message'] as String? ?? 
                          'Lỗi từ server: ${e.response!.statusCode}';
          } else if (errorData is String) {
            errorMessage = errorData;
          } else {
            errorMessage = 'Lỗi từ server: ${e.response!.statusCode} - ${e.response!.statusMessage}';
          }
        } else if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Kết nối timeout. Vui lòng kiểm tra kết nối mạng và thử lại.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Nhận dữ liệu timeout. File có thể quá lớn, vui lòng thử lại.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng.';
        } else {
          errorMessage = 'Lỗi kết nối: ${e.message ?? e.type.toString()}';
        }
      } else {
        errorMessage = 'Lỗi: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$errorMessage',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Import Stations from CSV',
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
                    Text(
                      'name, address, latitude, longitude, ports_250kw, ports_180kw, ports_150kw, ports_120kw, ports_80kw, ports_60kw, ports_40kw, ports_ac, operatingHours, parking, stationType, status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• parking: Paid, Free, or Unknown\n'
                      '• stationType: Public, Private, or Restricted\n'
                      '• status: active, inactive, or maintenance',
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
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: (_pickedFile != null && !_isUploading)
                              ? () {
                                  print('Import button pressed');
                                  _uploadFile();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: _isUploading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Importing...'),
                                  ],
                                )
                              : const Text('Import'),
                        ),
                      ],
                    ),
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

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (failureCount == 0 && successCount > 0) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Import thành công hoàn toàn';
    } else if (successCount > 0 && failureCount > 0) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Import một phần thành công';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Import thất bại';
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
                        'Tổng: $totalRows | Thành công: $successCount | Thất bại: $failureCount',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
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
                      child: _buildStatCard(theme, 'Tổng số', totalRows, Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(theme, 'Thành công', successCount, Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(theme, 'Thất bại', failureCount, Colors.red),
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
                        'Chi tiết từng trạm',
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
                        final stationName = result['stationName'] as String? ?? 'Unknown';
                        
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
                              'Dòng $rowNumber: $stationName',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: isSuccess
                                  ? Row(
                                      children: [
                                        Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ID: ${result['stationId']}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[700],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Lỗi:',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          result['errorMessage'] as String? ?? 'Unknown error',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            trailing: isSuccess
                                ? Icon(Icons.check, color: Colors.green)
                                : Icon(Icons.close, color: Colors.red),
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

