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
    final savedKey = ref.watch(apiKeyProvider);
    final apiKeyController = ref.read(apiKeyProvider.notifier);
    final inputController = useTextEditingController(text: savedKey ?? '');
    final theme = Theme.of(context);

    Future<void> save() async {
      final value = inputController.text.trim();
      await apiKeyController.setApiKey('openrouter', value);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              value.isEmpty
                  ? 'API key removed'
                  : 'API key saved for OpenRouter',
            ),
          ),
        );
      if (value.isNotEmpty) {
        ref.read(chatControllerProvider.notifier).loadModels();
      }
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
            _ApiKeyHelp(
              text:
                  'An API key is a secret token that lets this app call the '
                  'language model provider (e.g. OpenRouter) on your behalf. '
                  'It is stored only on this device via SharedPreferences.\n\n'
                  'How to get one:\n'
                  '1. Visit https://openrouter.ai/keys and sign in.\n'
                  '2. Click "Create Key", give it a name, and copy it.\n'
                  '3. Paste it here and tap Save.\n\n'
                  'Without a valid key, the Recruiter Copilot cannot answer '
                  'questions and shows a "not configured" banner.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: inputController,
              maxLines: 2,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-or-…',
                border: const OutlineInputBorder(),
                filled: true,
                suffixIcon: IconButton(
                  tooltip: savedKey == null ? 'Key not set' : 'Key is set',
                  icon: Icon(
                    savedKey == null
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
                label: const Text('Save API Key'),
              ),
            ),
            const SizedBox(height: 24),
            _ApiKeyStatus(
              icon: savedKey == null
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: savedKey == null
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              message: savedKey == null
                  ? 'No API key set. The Recruiter Copilot will show a '
                      '"not configured" banner until you save one.'
                  : 'API key is set. The Recruiter Copilot will reload '
                      'models from the backend on the next chat request.',
            ),
          ],
        ),
      ),
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
