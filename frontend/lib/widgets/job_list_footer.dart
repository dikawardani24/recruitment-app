import 'package:flutter/material.dart';

import '../providers.dart';

/// End-of-list status shared by the job list and job search screens: a
/// loading spinner while the next page loads, or a "no more" caption when the
/// last page has been reached.
class JobListFooter extends StatelessWidget {
  final JobListState state;

  const JobListFooter({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No more jobs',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
