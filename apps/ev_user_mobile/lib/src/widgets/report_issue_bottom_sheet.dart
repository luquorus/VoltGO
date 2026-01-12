import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/issue_providers.dart';

/// Issue Category Labels (mapped in feature layer, not hardcoded in shared)
class IssueCategoryLabels {
  static const Map<String, String> labels = {
    'LOCATION_WRONG': 'Location',
    'PRICE_WRONG': 'Price',
    'HOURS_WRONG': 'Hours',
    'PORTS_WRONG': 'Ports',
    'OTHER': 'Other',
  };

  static String getLabel(String category) {
    return labels[category] ?? category;
  }

  static List<String> get categories => labels.keys.toList();
}

/// Issue Status Labels (mapped in feature layer)
class IssueStatusLabels {
  static const Map<String, String> labels = {
    'OPEN': 'Open',
    'ACKNOWLEDGED': 'Acknowledged',
    'RESOLVED': 'Resolved',
    'REJECTED': 'Rejected',
  };

  static String getLabel(String status) {
    return labels[status] ?? status;
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.orange;
      case 'ACKNOWLEDGED':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Report Issue Bottom Sheet
class ReportIssueBottomSheet extends ConsumerStatefulWidget {
  final String stationId;
  final String stationName;

  const ReportIssueBottomSheet({
    super.key,
    required this.stationId,
    required this.stationName,
  });

  @override
  ConsumerState<ReportIssueBottomSheet> createState() =>
      _ReportIssueBottomSheetState();
}

class _ReportIssueBottomSheetState
    extends ConsumerState<ReportIssueBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      AppToast.showError(context, 'Please select a category');
      return;
    }

    final notifier = ref.read(reportIssueProvider.notifier);
    final response = await notifier.reportIssue(
      stationId: widget.stationId,
      category: _selectedCategory!,
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;

    if (response != null) {
      AppToast.showSuccess(context, 'Issue reported successfully');
      Navigator.of(context).pop();
    } else {
      final state = ref.read(reportIssueProvider);
      if (state.error != null) {
        AppToast.showError(context, state.error!.message);
      } else {
        AppToast.showError(context, 'Failed to report issue');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(reportIssueProvider);
    final tealColor = Colors.teal[800] ?? Colors.green[900] ?? Colors.teal;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Issue',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stationName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Category Dropdown
                  Text(
                    'Category',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tealColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      hintText: 'Select category',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: FaIcon(
                          FontAwesomeIcons.list,
                          color: tealColor,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tealColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    icon: FaIcon(
                      FontAwesomeIcons.chevronDown,
                      color: tealColor,
                      size: 16,
                    ),
                    dropdownColor: Colors.white,
                    style: TextStyle(color: tealColor),
                    items: IssueCategoryLabels.categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          IssueCategoryLabels.getLabel(category),
                          style: TextStyle(color: tealColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Description Field
                  Text(
                    'Description',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tealColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: tealColor),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue (10-2000 characters)',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: FaIcon(
                          FontAwesomeIcons.comment,
                          color: tealColor,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tealColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                    maxLines: 5,
                    minLines: 3,
                    maxLength: 2000,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(2000),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      if (value.trim().length > 2000) {
                        return 'Description must not exceed 2000 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  PrimaryButton(
                    label: state.isSubmitting
                        ? 'Submitting...'
                        : 'Submit Report',
                    onPressed: state.isSubmitting ? null : _handleSubmit,
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

