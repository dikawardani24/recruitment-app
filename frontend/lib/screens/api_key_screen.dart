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
    final selectedProvider = useState(ApiKeyProvider.gemini);
    final inputController = useTextEditingController(
      text: keys[selectedProvider.value.id] ?? '',
    );
    final theme = Theme.of(context);
    final provider = selectedProvider.value;

    Future<void> save() async {
      final value = inputController.text.trim();
      await apiKeyController.setApiKey(provider, value);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value.isEmpty
                  ? '${provider.label} key removed'
                  : '${provider.label} API key saved',
            ),
          ),
        );
      if (value.isNotEmpty) {
        ref.read(chatControllerProvider.notifier).loadModels();
      }
    }

    void selectProvider(ApiKeyProvider next) {
      if (next == provider) return;
      inputController.text = keys[next.id] ?? '';
      selectedProvider.value = next;
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
            Text('Provider', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<ApiKeyProvider>(
              initialValue: provider,
              items: [
                for (final p in ApiKeyProvider.values)
                  DropdownMenuItem(
                    value: p,
                    child: Row(
                      children: [
                        Icon(
                          p == ApiKeyProvider.gemini
                              ? Icons.auto_awesome
                              : Icons.router_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(p.label),
                        if (keys[p.id] != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) selectProvider(value);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),
            _ApiKeyHelp(
              text: _helpText(provider),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: inputController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: '${provider.label} API Key',
                hintText: provider.hint,
                border: const OutlineInputBorder(),
                filled: true,
                suffixIcon: IconButton(
                  tooltip:
                      keys[provider.id] == null ? 'Key not set' : 'Key is set',
                  icon: Icon(
                    keys[provider.id] == null
                        ? Icons.visibility_off
                        : Icons.verified_user_outlined,
                  ),
                  onPressed: null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save_outlined),
                label: Text('Save ${provider.label} API Key'),
              ),
            ),
            const SizedBox(height: 24),
            _ApiKeyStatus(
              icon: keys[provider.id] == null
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: keys[provider.id] == null
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              message: keys[provider.id] == null
                  ? 'No ${provider.label} API key set. The Recruiter Copilot '
                      'will use the server default key, or show a '
                      '"not configured" banner when none is available.'
                  : '${provider.label} API key is set. The Recruiter Copilot '
                      'will use it when this provider\'s model is selected.',
            ),
          ],
        ),
      ),
    );
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
