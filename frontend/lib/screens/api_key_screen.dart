import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/api_key_controller.dart';
import '../controllers/chat/chat_controller.dart';
import '../widgets/deferred_page.dart';
import '../widgets/gradient_header.dart';

class ApiKeyScreen extends StatelessWidget {
  const ApiKeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _ApiKeyContent());
  }
}

class _ApiKeyContent extends HookConsumerWidget {
  const _ApiKeyContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(apiKeyProvider);
    final apiKeyController = ref.read(apiKeyProvider.notifier);
    final geminiController = useTextEditingController();
    final openRouterController = useTextEditingController();
    final theme = Theme.of(context);

    Future<void> save(ApiKeyProvider provider, TextEditingController controller) async {
      final value = controller.text.trim();
      await apiKeyController.setApiKey(provider, value);
      controller.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${provider.label} API key saved')),
        );
      if (value.isNotEmpty) {
        ref.read(chatControllerProvider.notifier).loadModels();
      }
    }

    Future<void> remove(ApiKeyProvider provider) async {
      await apiKeyController.clearApiKey(provider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${provider.label} API key removed')),
        );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('API Key Configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GradientHeader(
              icon: Icons.key,
              title: 'API Key',
              subtitle: 'Configure API keys for AI models',
            ),
            const SizedBox(height: 24),
            _ProviderKeySection(
              provider: ApiKeyProvider.gemini,
              savedKey: keys[ApiKeyProvider.gemini.id],
              controller: geminiController,
              onSave: () => save(ApiKeyProvider.gemini, geminiController),
              onDelete: () => remove(ApiKeyProvider.gemini),
            ),
            const SizedBox(height: 24),
            _ProviderKeySection(
              provider: ApiKeyProvider.openrouter,
              savedKey: keys[ApiKeyProvider.openrouter.id],
              controller: openRouterController,
              onSave: () => save(ApiKeyProvider.openrouter, openRouterController),
              onDelete: () => remove(ApiKeyProvider.openrouter),
            ),
            const SizedBox(height: 8),
            Text(
              'When you set your own key, the copilot uses it directly and '
              'does not fall back to the server default. Without a key, the '
              'server default is used with automatic provider failover.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderKeySection extends StatelessWidget {
  const _ProviderKeySection({
    required this.provider,
    required this.savedKey,
    required this.controller,
    required this.onSave,
    required this.onDelete,
  });

  final ApiKeyProvider provider;
  final String? savedKey;
  final TextEditingController controller;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: savedKey == null
          ? _buildUnset(theme)
          : _buildSet(theme),
    );
  }

  Widget _buildUnset(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProviderHeader(provider: provider, isSet: false),
        const SizedBox(height: 16),
        _ApiKeyHelp(text: _helpText(provider)),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '${provider.label} API Key',
            hintText: provider.hint,
            border: const OutlineInputBorder(),
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined),
            label: Text('Save ${provider.label} API Key'),
          ),
        ),
        const SizedBox(height: 16),
        _ApiKeyStatus(
          icon: Icons.warning_amber_rounded,
          color: theme.colorScheme.error,
          message: 'No ${provider.label} API key set. The Recruiter Copilot '
              'will use the server default key (with automatic provider '
              'failover), or show a "not configured" banner when none is '
              'available.',
        ),
      ],
    );
  }

  Widget _buildSet(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProviderHeader(provider: provider, isSet: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _maskKey(savedKey!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ApiKeyStatus(
          icon: Icons.check_circle_outline,
          color: theme.colorScheme.primary,
          message: '${provider.label} API key is set. The Recruiter Copilot '
              'will use it when this provider\'s model is selected and will '
              'not fall back to the server default.',
        ),
      ],
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }

  String _helpText(ApiKeyProvider provider) {
    switch (provider) {
      case ApiKeyProvider.gemini:
        return 'The default provider runs on Google Gemini through the backend. '
            'It needs a Gemini API key for the chat copilot to answer.\n\n'
            'How to get one:\n'
            '1. Visit https://aistudio.google.com/apikey and sign in.\n'
            '2. Create an API key and copy it.\n'
            '3. Paste it here and tap Save.\n\n'
            'If the backend already sets ATS_LLM__API_KEY, this field is '
            'optional and the server default is used.';
      case ApiKeyProvider.openrouter:
        return 'OpenRouter lets the copilot switch between many models (e.g. '
            'Qwen). An API key here overrides the server default when an '
            'OpenRouter model is selected.\n\n'
            'How to get one:\n'
            '1. Visit https://openrouter.ai/keys and sign in.\n'
            '2. Click "Create Key", give it a name, and copy it.\n'
            '3. Paste it here and tap Save.\n\n'
            'Without a key, the backend uses its own OpenRouter key when '
            'configured.';
    }
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({required this.provider, required this.isSet});

  final ApiKeyProvider provider;
  final bool isSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          provider == ApiKeyProvider.gemini
              ? Icons.auto_awesome
              : Icons.router_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(provider.label, style: theme.textTheme.titleSmall),
        ),
        Icon(
          isSet ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: isSet
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _ApiKeyHelp extends StatelessWidget {
  final String text;

  const _ApiKeyHelp({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'What is an API key?',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyStatus extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const _ApiKeyStatus({
    required this.message,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
