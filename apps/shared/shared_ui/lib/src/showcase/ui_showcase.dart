import 'package:flutter/material.dart';
import '../../shared_ui.dart';

/// UI Showcase screen to demo all components
class UiShowcase extends StatefulWidget {
  const UiShowcase({super.key});

  @override
  State<UiShowcase> createState() => _UiShowcaseState();
}

class _UiShowcaseState extends State<UiShowcase> {
  final _searchController = TextEditingController();
  final _textController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'UI Showcase',
      isLoading: _isLoading,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Theme', _buildThemeSection()),
            _buildSection('Buttons', _buildButtonsSection()),
            _buildSection('Inputs', _buildInputsSection()),
            _buildSection('Cards', _buildCardsSection()),
            _buildSection('Badges', _buildBadgesSection()),
            _buildSection('States', _buildStatesSection()),
            _buildSection('Toast', _buildToastSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Primary Color',
            style: TextStyle(color: theme.colorScheme.onPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Secondary Color',
            style: TextStyle(color: theme.colorScheme.onSecondary),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('Surface Color'),
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrimaryButton(
          label: 'Primary Button',
          onPressed: () {
            setState(() => _isLoading = !_isLoading);
          },
          icon: Icons.check,
        ),
        PrimaryButton(
          label: 'Loading',
          isLoading: true,
        ),
        SecondaryButton(
          label: 'Secondary Button',
          onPressed: () {},
          icon: Icons.edit,
        ),
        DestructiveButton(
          label: 'Destructive',
          onPressed: () {},
          icon: Icons.delete,
        ),
      ],
    );
  }

  Widget _buildInputsSection() {
    return Column(
      children: [
        SearchField(
          controller: _searchController,
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Text Field',
          hint: 'Enter text...',
          controller: _textController,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'With Error',
          errorText: 'This field has an error',
        ),
      ],
    );
  }

  Widget _buildCardsSection() {
    return Column(
      children: [
        StationCard(
          title: 'EV Station Hanoi Center',
          subtitle: '123 Nguyen Du, Hoan Kiem, Hanoi',
          badges: [
            StatusPill(label: 'PUBLIC'),
            StatusPill(label: 'OPEN'),
          ],
          trailing: ScoreBadge(score: 85, label: 'Trust'),
          onTap: () {},
        ),
        const SizedBox(height: 12),
        TaskCard(
          title: 'Verification Task #123',
          subtitle: 'Station: EV Station Hanoi Center',
          statusPill: StatusPill(label: 'ASSIGNED'),
          priority: 7,
          slaDueAt: DateTime.now().add(const Duration(hours: 24)),
          onTap: () {},
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Information Card',
          children: [
            const Text('This is a generic info card.'),
            const SizedBox(height: 8),
            const Text('It can contain any content.'),
          ],
        ),
        const SizedBox(height: 12),
        AuditCard(
          action: 'CHANGE_REQUEST_APPROVED',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          actorEmail: 'admin@voltgo.com',
          actorRole: 'ADMIN',
          metadata: {'stationId': 'abc-123', 'version': '2'},
        ),
      ],
    );
  }

  Widget _buildBadgesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: 'DRAFT'),
            StatusPill(label: 'PENDING'),
            StatusPill(label: 'APPROVED'),
            StatusPill(label: 'REJECTED'),
            StatusPill(label: 'PUBLISHED'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ScoreBadge(score: 95, label: 'Trust', isTrustScore: true),
            ScoreBadge(score: 75, label: 'Trust', isTrustScore: true),
            ScoreBadge(score: 45, label: 'Trust', isTrustScore: true),
            ScoreBadge(score: 25, label: 'Risk', isTrustScore: false),
            ScoreBadge(score: 55, label: 'Risk', isTrustScore: false),
          ],
        ),
      ],
    );
  }

  Widget _buildStatesSection() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LoadingState(message: 'Loading data...'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: EmptyState(
            message: 'No items found',
            icon: Icons.inbox_outlined,
            action: PrimaryButton(
              label: 'Refresh',
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ErrorState(
            message: 'Failed to load data',
            onRetry: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildToastSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrimaryButton(
          label: 'Show Success',
          onPressed: () {
            AppToast.showSuccess(context, 'Operation completed successfully!');
          },
        ),
        PrimaryButton(
          label: 'Show Error',
          onPressed: () {
            AppToast.showError(context, 'Something went wrong!');
          },
        ),
        PrimaryButton(
          label: 'Show Info',
          onPressed: () {
            AppToast.showInfo(context, 'This is an info message.');
          },
        ),
        PrimaryButton(
          label: 'Show Warning',
          onPressed: () {
            AppToast.showWarning(context, 'This is a warning message.');
          },
        ),
      ],
    );
  }
}

