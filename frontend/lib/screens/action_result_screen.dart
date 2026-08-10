import 'package:flutter/material.dart';

import '../navigation/app_navigator.dart';
import '../widgets/deferred_page.dart';

/// Full-screen result page shown after a delete attempt: a green check for
/// success or a red error for failure, with a single Done button that pops.
class ActionResultScreen extends StatelessWidget {
  final ActionResultData data;

  const ActionResultScreen({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return DeferredPage(child: _ActionResultContent(data: data));
  }
}

class _ActionResultContent extends StatelessWidget {
  final ActionResultData data;

  const _ActionResultContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.success ? Colors.green : theme.colorScheme.error;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 56,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (data.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  data.message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
