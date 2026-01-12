import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/upload_providers.dart';
import '../providers/task_providers.dart';
import '../services/upload_service.dart';
import '../models/verification_task.dart';

/// Evidence Upload Stepper Widget
/// 3 steps: Pick -> Upload -> Submit
class EvidenceUploadStepper extends ConsumerStatefulWidget {
  final VerificationTask task;
  final VoidCallback onSuccess;

  const EvidenceUploadStepper({
    super.key,
    required this.task,
    required this.onSuccess,
  });

  @override
  ConsumerState<EvidenceUploadStepper> createState() => _EvidenceUploadStepperState();
}

class _EvidenceUploadStepperState extends ConsumerState<EvidenceUploadStepper> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  XFile? _selectedXFile; // For web compatibility
  Uint8List? _imageBytes; // For web image display
  String? _objectKey;
  String? _uploadUrl;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  bool _isSubmitting = false;
  final TextEditingController _noteController = TextEditingController();

  int _currentStep = 0; // 0: Pick, 1: Upload, 2: Submit

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit Evidence',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Stepper
            Stepper(
              currentStep: _currentStep,
              onStepContinue: _handleStepContinue,
              onStepCancel: _handleStepCancel,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      if (details.stepIndex < 2)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            child: Text(_getStepButtonText(details.stepIndex)),
                          ),
                        ),
                      if (details.stepIndex > 0) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // Step 1: Pick Image
                Step(
                  title: const Text('Pick Image'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedImage != null || _imageBytes != null) ...[
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb && _imageBytes != null
                                  ? Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                        )
                                      : const SizedBox(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.change_circle),
                            label: const Text('Change Image'),
                          ),
                        ] else
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Pick Image'),
                          ),
                      ],
                    ),
                  isActive: _currentStep >= 0,
                  state: (_selectedImage != null || _imageBytes != null)
                      ? StepState.complete
                      : StepState.indexed,
                ),
                
                // Step 2: Upload
                Step(
                  title: const Text('Upload'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isUploading) ...[
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: 8),
                        Text(
                          'Uploading: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ] else if (_objectKey != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Upload completed',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        const Text('Ready to upload'),
                    ],
                  ),
                  isActive: _currentStep >= 1,
                  state: _objectKey != null
                      ? StepState.complete
                      : (_isUploading ? StepState.editing : StepState.indexed),
                ),
                
                // Step 3: Submit
                Step(
                  title: const Text('Submit'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Note (optional)',
                        controller: _noteController,
                        maxLines: 3,
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      if (_isSubmitting)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                  isActive: _currentStep >= 2,
                  state: StepState.indexed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStepButtonText(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return 'Continue';
      case 1:
        return _isUploading ? 'Uploading...' : 'Upload';
      case 2:
        return _isSubmitting ? 'Submitting...' : 'Submit';
      default:
        return 'Continue';
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedXFile = image;
          if (kIsWeb) {
            // For web, read bytes directly
            image.readAsBytes().then((bytes) {
              if (mounted) {
                setState(() {
                  _imageBytes = bytes;
                });
              }
            });
          } else {
            _selectedImage = File(image.path);
          }
          _objectKey = null; // Reset upload state
          _uploadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _handleStepContinue() async {
    switch (_currentStep) {
      case 0:
        // Validate image selected
        if (_selectedImage == null && _imageBytes == null) {
          AppToast.showError(context, 'Please pick an image first');
          return;
        }
        setState(() {
          _currentStep = 1;
        });
        break;
        
      case 1:
        // Upload image
        if (_objectKey != null) {
          // Already uploaded, go to next step
          setState(() {
            _currentStep = 2;
          });
          return;
        }
        await _uploadImage();
        break;
        
      case 2:
        // Submit evidence
        if (_objectKey == null) {
          AppToast.showError(context, 'Please upload image first');
          return;
        }
        await _submitEvidence();
        break;
    }
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null && _imageBytes == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final uploadService = ref.read(uploadServiceProvider);
      
      // Step 1: Get presigned URL
      final presignResponse = await uploadService.presignUpload(
        contentType: 'image/jpeg',
      );
      
      setState(() {
        _uploadUrl = presignResponse.uploadUrl;
      });

      // Step 2: Upload file
      if (kIsWeb && _imageBytes != null) {
        // For web, upload bytes directly
        await uploadService.uploadFileBytes(
          uploadUrl: presignResponse.uploadUrl,
          fileBytes: _imageBytes!,
          contentType: 'image/jpeg',
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      } else if (_selectedImage != null) {
        // For mobile, upload File
        await uploadService.uploadFile(
          uploadUrl: presignResponse.uploadUrl,
          file: _selectedImage!,
          contentType: 'image/jpeg',
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );
      }

      setState(() {
        _objectKey = presignResponse.objectKey;
        _isUploading = false;
        _currentStep = 2; // Move to submit step
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        AppToast.showError(context, 'Upload failed: ${e.toString()}');
      }
    }
  }

  Future<void> _submitEvidence() async {
    if (_objectKey == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final params = SubmitEvidenceParams(
        taskId: widget.task.id,
        photoObjectKey: _objectKey!,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      await ref.read(submitEvidenceProvider(params));

      // Refresh task detail
      ref.invalidate(taskDetailProvider(widget.task.id));
      ref.invalidate(tasksByStatusProvider(null));

      if (mounted) {
        AppToast.showSuccess(context, 'Evidence submitted successfully!');
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to submit evidence: ${e.toString()}');
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

