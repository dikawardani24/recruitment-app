import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/api_key_controller.dart';
import '../controllers/chat/chat_controller.dart';
import '../domain/models.dart';
import '../providers.dart';
import '../theme/theme_controller.dart';
import '../widgets/deferred_page.dart';
import '../widgets/gradient_header.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _SettingsContent());
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);
    final navigator = ref.read(navigatorProvider);
    final chatModels = ref.watch(chatControllerProvider.select((s) => s.models));
    final apiKeys = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GradientHeader(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Customize how the app looks and behaves.',
          ),
          const SizedBox(height: 16),
          const SectionTitle('How to use'),
          const SizedBox(height: 8),
          const _GettingStartedCard(),
          const SizedBox(height: 16),
          const SectionTitle('AI Models'),
          const SizedBox(height: 8),
          SectionCard(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('API Key Configuration'),
                  subtitle: const Text(
                    'Set API keys for chat models',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: navigator.goToApiKey,
                ),
                const Divider(height: 1),
                for (final status in _modelStatuses(chatModels, apiKeys))
                  _ModelStatusTile(status: status),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Appearance'),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Theme',
            crossAxisAlignment: CrossAxisAlignment.stretch,
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (mode) {
                if (mode != null) themeController.setMode(mode);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('System'),
                    subtitle: Text('Follow your device setting'),
                    secondary: Icon(Icons.brightness_auto),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Light'),
                    subtitle: Text('Always use the light theme'),
                    secondary: Icon(Icons.light_mode_outlined),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Dark'),
                    subtitle: Text('Always use the dark theme'),
                    secondary: Icon(Icons.dark_mode_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step-by-step guide to the core workflow, shown on the Settings screen.
class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: const Column(
        children: [
          _StepItem(
            icon: Icons.work_outline,
            title: '1. Create a job',
            detail: 'Paste a job description or upload a JD file (PDF/DOCX/TXT). '
                'Skills, experience and education are extracted automatically.',
          ),
          _StepItem(
            icon: Icons.upload_file_outlined,
            title: '2. Add candidates',
            detail: 'Upload CVs (PDF/DOCX/TXT) to the job. Each CV is parsed '
                'in the background.',
          ),
          _StepItem(
            icon: Icons.auto_awesome,
            title: '3. Rank candidates',
            detail: 'Tap Rank to score every CV and order them by best match, '
                'with reasoning and a recommendation.',
          ),
          _StepItem(
            icon: Icons.manage_search_outlined,
            title: '4. Review rankings',
            detail: 'Check match scores, strengths, weaknesses and skill gaps. '
                'Tap a candidate to see full details.',
          ),
          _StepItem(
            icon: Icons.search,
            title: '5. Search & ask',
            detail: 'Use unified search across jobs and candidates, and ask the '
                'recruiter copilot anything about your workspace.',
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _StepItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Availability of one chat provider for the Recruiter Copilot.
class _ModelStatus {
  const _ModelStatus({
    required this.provider,
    required this.available,
    required this.detail,
    required this.isUserConfigured,
  });

  final ApiKeyProvider provider;
  final bool available;
  final String detail;
  final bool isUserConfigured;
}

List<_ModelStatus> _modelStatuses(
  List<ChatModel> models,
  Map<String, String?> apiKeys,
) {
  return [
    for (final provider in ApiKeyProvider.values) _modelStatus(provider, models, apiKeys),
  ];
}

_ModelStatus _modelStatus(
  ApiKeyProvider provider,
  List<ChatModel> models,
  Map<String, String?> apiKeys,
) {
  final userKey = apiKeys[provider.id];
  if (userKey?.isNotEmpty == true) {
    return _ModelStatus(
      provider: provider,
      available: true,
      isUserConfigured: true,
      detail: 'Using your saved key',
    );
  }
  final serverModel = models.where((m) => m.provider == provider.id).firstOrNull;
  if (serverModel != null) {
    return _ModelStatus(
      provider: provider,
      available: true,
      isUserConfigured: false,
      detail: 'App default (${serverModel.label})',
    );
  }
  return _ModelStatus(
    provider: provider,
    available: false,
    isUserConfigured: false,
    detail: 'Not configured',
  );
}

class _ModelStatusTile extends StatelessWidget {
  const _ModelStatusTile({required this.status});

  final _ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status.available
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      leading: Icon(
        status.provider == ApiKeyProvider.gemini
            ? Icons.auto_awesome
            : Icons.router_outlined,
        color: color,
      ),
      title: Text(status.provider.label),
      subtitle: Text(status.detail)
    );
  }
}
