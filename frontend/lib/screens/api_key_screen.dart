import 'package:ai_ats/widgets/card_shape.dart';
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
    final keyInputController = useTextEditingController();

    // Get list of providers that have a key set (exclude empty strings)
    final savedProviders = ApiKeyProvider.values
        .where((p) => (keys[p.id]?.isNotEmpty) == true)
        .toList();

    // Get list of providers that DON'T have a key set
    final availableProviders = ApiKeyProvider.values
        .where((p) => (keys[p.id]?.isNotEmpty) != true)
        .toList();

    // Dropdown state
    final selectedProvider = useState<ApiKeyProvider?>(
      availableProviders.isNotEmpty ? availableProviders.first : null,
    );

    // Sync dropdown if available providers change (e.g. after adding/deleting)
    useEffect(() {
      if (selectedProvider.value == null && availableProviders.isNotEmpty) {
        selectedProvider.value = availableProviders.first;
      } else if (selectedProvider.value != null &&
          !availableProviders.contains(selectedProvider.value)) {
        selectedProvider.value = availableProviders.isNotEmpty
            ? availableProviders.first
            : null;
      }
      return null;
    }, [availableProviders]);

    Future<void> save() async {
      final provider = selectedProvider.value;
      if (provider == null) return;

      final value = keyInputController.text.trim();
      if (value.isEmpty) return;

      await apiKeyController.setApiKey(provider, value);
      keyInputController.clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${provider.label} API key saved')),
        );

      ref.read(chatControllerProvider.notifier).loadModels();
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
            const _HelpCard(),
            const SizedBox(height: 24),

            // Section 1: Saved API Keys (Visible if any key is set)
            if (savedProviders.isNotEmpty) ...[
              Text(
                'Saved API Keys',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...savedProviders.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SavedKeyItem(
                    provider: p,
                    maskedKey: _maskKey(keys[p.id]!),
                    onDelete: () => remove(p),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Section 2: Add API Key (Visible if 0 or 1 key is set)
            if (savedProviders.length < 2) ...[
              Text(
                'Add API Key',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _AddKeyForm(
                availableProviders: availableProviders,
                selectedProvider: selectedProvider.value,
                onProviderChanged: (p) => selectedProvider.value = p,
                controller: keyInputController,
                onSave: save,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: cardShape(Theme.of(context)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('What is an API key?', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'API keys allow the app to connect to AI models directly using your account. '
              'This overrides server defaults for both the Recruiter Copilot and Candidate Ranking.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _HelpItem(
              title: 'Google Gemini',
              url: 'https://aistudio.google.com/apikey',
              instructions: 'Sign in, create an API key, and paste it here.',
            ),
            const SizedBox(height: 12),
            _HelpItem(
              title: 'OpenRouter',
              url: 'https://openrouter.ai/keys',
              instructions:
                  'Sign in, create a key, and paste it here to access various models.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String title;
  final String url;
  final String instructions;

  const _HelpItem({
    required this.title,
    required this.url,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(instructions, style: theme.textTheme.bodySmall),
        Text(
          url,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}

class _SavedKeyItem extends ConsumerWidget {
  final ApiKeyProvider provider;
  final String maskedKey;
  final VoidCallback onDelete;

  const _SavedKeyItem({
    required this.provider,
    required this.maskedKey,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: cardShape(Theme.of(context)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              provider == ApiKeyProvider.gemini
                  ? Icons.auto_awesome
                  : Icons.router_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.label, style: theme.textTheme.labelLarge),
                  Text(
                    maskedKey,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              tooltip: 'Delete Key',
            ),
          ],
        ),
      ),
    );
  }
}

class _AddKeyForm extends StatelessWidget {
  final List<ApiKeyProvider> availableProviders;
  final ApiKeyProvider? selectedProvider;
  final ValueChanged<ApiKeyProvider?> onProviderChanged;
  final TextEditingController controller;
  final VoidCallback onSave;

  const _AddKeyForm({
    required this.availableProviders,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: cardShape(Theme.of(context)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<ApiKeyProvider>(
              value: selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Select Provider',
                border: OutlineInputBorder(),
              ),
              items: availableProviders
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: onProviderChanged,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: selectedProvider != null
                    ? '${selectedProvider!.label} API Key'
                    : 'API Key',
                hintText: selectedProvider?.hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedProvider != null ? onSave : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save API Key'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
