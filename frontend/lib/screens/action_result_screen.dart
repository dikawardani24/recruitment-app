import 'package:flutter/material.dart';

/// Full-screen result page shown after a delete attempt: a green check for
/// success or a red error for failure, with a single Done button that pops.
class ActionResultScreen extends StatelessWidget {
  final bool success;
  final String title;
  final String? message;
  final String buttonLabel;

  const ActionResultScreen({
    super.key,
    required this.success,
    required this.title,
    this.message,
    this.buttonLabel = 'Done',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success ? Colors.green : theme.colorScheme.error;
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
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  size: 56,
                  color: color,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
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
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes [ActionResultScreen] and resolves once the user dismisses it.
Future<void> showActionResult(
  BuildContext context, {
  required bool success,
  required String title,
  String? message,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) =>
          ActionResultScreen(success: success, title: title, message: message),
    ),
  );
}
