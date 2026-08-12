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

/// Availability of one chat provider for the Recruiter Copilot.
class _ModelStatus {
  const _ModelStatus({
    required this.provider,
    required this.available,
    required this.detail,
  });

  final ApiKeyProvider provider;
  final bool available;
  final String detail;
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
  if (userKey != null) {
    return _ModelStatus(provider: provider, available: true, detail: 'Using your saved key');
  }
  final serverModel = models.where((m) => m.provider == provider.id).firstOrNull;
  if (serverModel != null) {
    return _ModelStatus(
      provider: provider,
      available: true,
      detail: 'App default (${serverModel.label})',
    );
  }
  return _ModelStatus(provider: provider, available: false, detail: 'Not configured');
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
      subtitle: Text(status.detail),
      trailing: Icon(
        status.available ? Icons.check_circle : Icons.radio_button_unchecked,
        color: color,
        size: 18,
      ),
    );
  }
}
