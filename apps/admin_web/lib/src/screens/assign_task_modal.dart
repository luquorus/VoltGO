import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../theme/admin_theme.dart';
import '../models/collaborator_candidate.dart';

/// Provider for loading candidates
final candidatesProvider = FutureProvider.family<CandidateListResponse, CandidatesParams>((ref, params) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');
  
  final response = await factory.admin.getCollaboratorCandidates(
    taskId: params.taskId,
    onlyActiveContract: params.onlyActiveContract,
    includeUnlocated: params.includeUnlocated,
  );
  
  return CandidateListResponse.fromJson(response);
});

class CandidatesParams {
  final String taskId;
  final bool onlyActiveContract;
  final bool includeUnlocated;

  CandidatesParams({
    required this.taskId,
    this.onlyActiveContract = true,
    this.includeUnlocated = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CandidatesParams &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId &&
          onlyActiveContract == other.onlyActiveContract &&
          includeUnlocated == other.includeUnlocated;

  @override
  int get hashCode => taskId.hashCode ^ onlyActiveContract.hashCode ^ includeUnlocated.hashCode;
}

/// Assign Task Modal with Candidates Selection
class AssignTaskModal extends ConsumerStatefulWidget {
  final String taskId;

  const AssignTaskModal({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<AssignTaskModal> createState() => _AssignTaskModalState();
}

class _AssignTaskModalState extends ConsumerState<AssignTaskModal> {
  bool _onlyActiveContract = true;
  bool _includeUnlocated = false;
  bool _isAssigning = false;
  CollaboratorCandidate? _selectedCandidate;
  bool _useFallback = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  CandidatesParams get _params => CandidatesParams(
        taskId: widget.taskId,
        onlyActiveContract: _onlyActiveContract,
        includeUnlocated: _includeUnlocated,
      );

  Future<void> _handleAssign() async {
    if (_useFallback) {
      if (_emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter collaborator email'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_selectedCandidate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a collaborator'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      if (_useFallback) {
        await factory.admin.assignVerificationTask(
          id: widget.taskId,
          collaboratorEmail: _emailController.text.trim(),
        );
      } else {
        await factory.admin.assignVerificationTask(
          id: widget.taskId,
          collaboratorUserId: _selectedCandidate!.collaboratorUserId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidatesAsync = ref.watch(candidatesProvider(_params));

    return Dialog(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Task',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Task ID: ${widget.taskId.substring(0, 8)}...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Active Contract Only'),
                    selected: _onlyActiveContract,
                    onSelected: (v) => setState(() => _onlyActiveContract = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Show Unlocated'),
                    selected: _includeUnlocated,
                    onSelected: (v) => setState(() => _includeUnlocated = v),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _useFallback = !_useFallback),
                    icon: Icon(_useFallback ? Icons.list : Icons.edit),
                    label: Text(_useFallback ? 'Show Candidates' : 'Enter Email'),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _useFallback
                  ? _buildFallbackInput(theme)
                  : candidatesAsync.when(
                      data: (data) => _buildCandidatesList(theme, data),
                      loading: () => const Center(child: LoadingState(message: 'Loading candidates...')),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: ErrorState(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(candidatesProvider(_params)),
                        ),
                      ),
                    ),
            ),

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isAssigning ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isAssigning ? null : _handleAssign,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isAssigning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Assign'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInput(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manual Assignment',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the collaborator email to assign this task. This is a fallback option.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Collaborator Email',
              hintText: 'e.g. collab1@local',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildCandidatesList(ThemeData theme, CandidateListResponse data) {
    if (data.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No collaborators found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting filters or use the email fallback option.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: data.candidates.length,
      itemBuilder: (context, index) {
        final candidate = data.candidates[index];
        final isSelected = _selectedCandidate?.collaboratorUserId == candidate.collaboratorUserId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? AdminTheme.primaryTeal.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? AdminTheme.primaryTeal : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedCandidate = candidate),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor: isSelected ? AdminTheme.primaryTeal : AdminTheme.surfaceLight,
                    child: Text(
                      candidate.initial,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AdminTheme.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              candidate.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (candidate.contractActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (candidate.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            candidate.phone!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Stats
                  _buildStatChip(
                    context,
                    icon: Icons.check_circle_outline,
                    label: '${candidate.stats.completed}',
                    color: Colors.green,
                    tooltip: 'Completed',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    context,
                    icon: Icons.pending_outlined,
                    label: '${candidate.stats.active}',
                    color: Colors.orange,
                    tooltip: 'Active',
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    context,
                    icon: Icons.warning_amber_outlined,
                    label: '${candidate.stats.failedOrOverdue}',
                    color: Colors.red,
                    tooltip: 'Failed/Overdue',
                  ),
                  const SizedBox(width: 16),

                  // Distance
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 16,
                            color: candidate.distanceMeters != null
                                ? AdminTheme.primaryTeal
                                : theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            candidate.distanceKm,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: candidate.distanceMeters != null
                                  ? AdminTheme.primaryTeal
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      if (candidate.location?.updatedAt != null)
                        Text(
                          _formatTimeAgo(candidate.location!.updatedAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),

                  // Radio indicator
                  const SizedBox(width: 12),
                  Radio<String>(
                    value: candidate.collaboratorUserId,
                    groupValue: _selectedCandidate?.collaboratorUserId,
                    onChanged: (v) => setState(() => _selectedCandidate = candidate),
                    activeColor: AdminTheme.primaryTeal,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
