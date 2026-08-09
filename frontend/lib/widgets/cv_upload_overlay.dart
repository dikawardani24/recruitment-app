import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/upload_controller.dart';

/// Shows upload progress while CV files are submitted in batches. Closes once
/// the recruiter taps Done — background processing continues on the backend.
Future<void> showCvUploadOverlay(BuildContext context, String jobId) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UploadOverlay(jobId: jobId),
  );
}

class _UploadOverlay extends ConsumerWidget {
  const _UploadOverlay({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);

    return PopScope(
      canPop: state.completed,
      child: AlertDialog(
        title: Text(state.completed ? 'Submission complete' : 'Uploading CVs…'),
        content: _content(context, state),
        actions: state.completed
            ? [
                if (state.hasFailures)
                  TextButton(
                    onPressed: () => controller.retryFailed(jobId),
                    child: const Text('Retry failed'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ]
            : null,
      ),
    );
  }
}

Widget _content(BuildContext context, UploadState state) {
  final theme = Theme.of(context);

  if (state.uploading) {
    final percent = (state.fraction * 100).round();
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${state.uploadedFiles} / ${state.totalFiles} files submitted',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.fraction,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent%',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (state.totalBatches > 1)
            Text(
              'Batch ${state.currentBatch} of ${state.totalBatches}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          Text(
            'Submitting files to the server. CV processing runs in the '
            'background afterwards.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  if (state.completed) {
    final ok = state.uploadedFiles;
    final failed = state.failedFiles;
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            failed > 0 ? Icons.warning_amber_rounded : Icons.check_circle,
            color: failed > 0
                ? theme.colorScheme.error
                : Colors.green.shade600,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            '$ok CVs submitted successfully',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (failed > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$failed ${failed == 1 ? 'file' : 'files'} failed to upload.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Candidate processing will continue in the background. '
            'You can leave this page now.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  return const Text('Preparing…');
}
