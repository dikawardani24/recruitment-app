import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/jobDetail/job_detail_controller.dart';
import '../domain/models.dart';
import '../providers.dart';
import '../widgets/accent_chip.dart';
import '../widgets/bucket_donut.dart';
import '../widgets/deferred_page.dart';
import '../widgets/ranked_by_info.dart';
import '../widgets/score_color.dart';

/// Full-screen page with a candidate's ranking details, opened from the job
/// detail and rankings screens. Supports ranking this CV (when it is ready)
/// and deleting it. The page stays in sync with `cvsProvider(jobId)` so the
/// details refresh after a rank or delete.
class CandidateDetailScreen extends StatelessWidget {
  final String jobId;
  final String cvId;

  /// The candidate as passed by the opening screen, used to render instantly
  /// while `cvsProvider(jobId)` loads and as a fallback when the candidate
  /// cannot be matched (e.g. it was not returned by the CV list).
  final CandidateResult? initial;

  const CandidateDetailScreen({
    super.key,
    required this.jobId,
    required this.cvId,
    this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return DeferredPage(
      child: _CandidateDetailContent(
        jobId: jobId,
        cvId: cvId,
        initial: initial,
      ),
    );
  }
}

class _CandidateDetailContent extends HookConsumerWidget {
  final String jobId;
  final String cvId;
  final CandidateResult? initial;

  const _CandidateDetailContent({
    required this.jobId,
    required this.cvId,
    this.initial,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cvsAsync = ref.watch(cvsProvider(jobId));
    final detailController = ref.read(jobDetailControllerProvider);
    final ranking = useState(false);

    final candidate = _resolveCandidate(cvsAsync.value, cvId, initial);

    if (candidate == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Candidate')),
        body: Center(
          child: cvsAsync.isLoading
              ? const CircularProgressIndicator()
              : Text(cvsAsync.hasError ? '${cvsAsync.error}' : 'Candidate not found.'),
        ),
      );
    }

    final cv = candidate;
    final score = cv.overallScore;
    final canRank =
        cv.cvId != null && (cv.status == 'completed' || cv.status == 'ranked');

    return Scaffold(
      appBar: AppBar(
        title: Text(cv.candidateName ?? 'Candidate'),
        actions: [
          if (cv.cvId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete candidate',
              onPressed: () async {
                final deleted = await detailController.deleteCv(jobId, cv);
                if (deleted && context.mounted) {
                  ref.read(navigatorProvider).pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cv.candidateName ?? cv.fileName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(cv.fileName, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 16),
              if (canRank) ...[
                _RankCvButton(
                  label: score == null ? 'Rank this CV' : 'Re-rank CV',
                  busy: ranking.value,
                  onPressed: () async {
                    ranking.value = true;
                    try {
                      await detailController.rankCv(context, jobId, cv);
                    } finally {
                      if (context.mounted) ranking.value = false;
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (score != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Match Score',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(score * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scoreColor(score),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recommendation',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatBucket(cv.bucket ?? 'weak_match'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: getBucketColor(cv.bucket ?? 'weak_match'),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (cv.rankedBy != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ranked by',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RankedByInfoRow(rankedBy: cv.rankedBy),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      cv.status.isEmpty ? 'uploaded' : cv.status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (cv.status == 'failed' && cv.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(cv.error!, style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This candidate has not been ranked yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (cv.skills.isNotEmpty) ...[
                const CandidateSectionLabel(
                  icon: Icons.bolt,
                  label: 'SKILLS',
                  color: Colors.indigo,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cv.skills
                      .map(
                        (skill) =>
                            AccentChip(label: skill, accent: Colors.indigo),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (cv.yearsExperience != null && cv.yearsExperience! > 0) ...[
                const CandidateSectionLabel(
                  icon: Icons.work_history,
                  label: 'EXPERIENCE',
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatYears(cv.yearsExperience!),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              if (cv.education != null && cv.education!.isNotEmpty) ...[
                const CandidateSectionLabel(
                  icon: Icons.school,
                  label: 'EDUCATION',
                  color: Colors.teal,
                ),
                const SizedBox(height: 8),
                Text(cv.education!, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              if (cv.certifications.isNotEmpty) ...[
                const CandidateSectionLabel(
                  icon: Icons.workspace_premium,
                  label: 'CERTIFICATIONS',
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cv.certifications
                      .map(
                        (cert) => AccentChip(
                          label: cert,
                          accent: Colors.deepPurple,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (cv.strengths.isNotEmpty) ...[
                const CandidateSectionLabel(
                  icon: Icons.check_circle,
                  label: 'STRENGTHS',
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cv.strengths
                      .map(
                        (skill) => AccentChip(label: skill, accent: Colors.green),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (cv.skillGaps.isNotEmpty) ...[
                const CandidateSectionLabel(
                  icon: Icons.warning,
                  label: 'MISSING SKILLS',
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cv.skillGaps
                      .map((gap) => AccentChip(label: gap, accent: Colors.red))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (cv.recommendation != null) ...[
                Text(
                  'Recommendation',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cv.recommendation!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
              ],
              if (cv.explanation != null) ...[
                Text(
                  'Explanation',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(cv.explanation!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
              ],
              if (cv.weaknesses.isNotEmpty)
                CandidateBulletList(
                  title: 'Areas to probe',
                  items: cv.weaknesses,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Picks the freshest version of the candidate from the CV list, falling back
/// to [initial] while loading or when the CV is not returned by the API.
CandidateResult? _resolveCandidate(
  List<CandidateResult>? cvs,
  String cvId,
  CandidateResult? initial,
) {
  if (cvs != null) {
    for (final c in cvs) {
      if (c.cvId != null && c.cvId == cvId) return c;
    }
    if (initial != null) {
      for (final c in cvs) {
        if (c.fileName == initial.fileName) return c;
      }
    }
  }
  return initial;
}

class _RankCvButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _RankCvButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(busy ? 'Ranking…' : label),
    );
  }
}

class CandidateSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const CandidateSectionLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _formatYears(double years) {
  final rounded = years.roundToDouble();
  final isWhole = (years - rounded).abs() < 0.05;
  final text = isWhole ? rounded.toStringAsFixed(0) : years.toStringAsFixed(1);
  return '$text year${years == 1 ? '' : 's'}';
}

class CandidateBulletList extends StatelessWidget {
  final String title;
  final List<String> items;

  const CandidateBulletList({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
