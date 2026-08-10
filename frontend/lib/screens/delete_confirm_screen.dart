import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../navigation/app_navigator.dart';
import '../widgets/bucket_donut.dart';
import '../widgets/section_card.dart';
import 'job_list_screen.dart' show formatCreatedAt;

/// Affected-data preview for deleting a whole job: the job's attributes plus
/// the names of every candidate that will be removed with it.
Widget jobDeleteDetails(Job job, List<CandidateResult> candidates) {
  final names = candidates
      .map((c) => c.candidateName ?? c.fileName)
      .where((n) => n.isNotEmpty)
      .toList();
  return DeleteDetailsCard(
    title: job.title,
    rows: [('Status', job.status), ('Created', formatCreatedAt(job.createdAt))],
    names: names,
    namesTitle: candidates.length == 1 ? 'Candidate' : 'Candidates',
  );
}

/// Affected-data preview for deleting a single candidate.
Widget candidateDeleteDetails(CandidateResult cv) {
  final score = cv.overallScore;
  return DeleteDetailsCard(
    title: 'Candidate',
    rows: [
      ('Name', cv.candidateName ?? cv.fileName),
      ('File', cv.fileName),
      ('Status', cv.status),
      if (score != null) ('Score', '${(score * 100).round()}%'),
      if (cv.bucket != null && cv.bucket!.isNotEmpty)
        ('Match', formatBucket(cv.bucket!)),
      if (cv.education != null && cv.education!.isNotEmpty)
        ('Education', cv.education!),
    ],
    names: cv.skills,
    namesTitle: 'Skills',
  );
}

/// Full-screen confirmation shown before a destructive delete. Pops with
/// `true` when the user taps the delete button and `false` on cancel or back.
/// The [data.details] list renders the affected-data preview (what will be
/// lost).
class DeleteConfirmScreen extends StatelessWidget {
  final DeleteConfirmData data;

  const DeleteConfirmScreen({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm deletion')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, size: 40, color: errorColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (data.details.isNotEmpty)
              ...[const SizedBox(height: 20), ...data.details],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: errorColor,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(data.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card listing key/value attributes of the affected record, followed by the
/// names of the records that will be deleted with it.
class DeleteDetailsCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final List<String> names;
  final String namesTitle;

  const DeleteDetailsCard({
    super.key,
    required this.title,
    this.rows = const [],
    this.names = const [],
    this.namesTitle = 'Candidates',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const previewLimit = 10;

    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(value, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '$namesTitle (${names.length})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final name in names.take(previewLimit))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (names.length > previewLimit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'and ${names.length - previewLimit} more',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
