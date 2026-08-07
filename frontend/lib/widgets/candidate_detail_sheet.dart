import 'package:flutter/material.dart';

import '../models.dart';
import 'bucket_donut.dart';
import 'score_color.dart';

/// Modal bottom sheet with a candidate's ranking details, matching the one
/// used on the rankings screen. Safe to open for candidates that have not
/// been ranked yet — ranking-only sections are hidden and the status is shown
/// instead, plus a button to rank this CV when [onRank] is provided.
void showCandidateDetailSheet(
  BuildContext context,
  CandidateResult c, {
  Future<void> Function()? onRank,
}) {
  final theme = Theme.of(context);
  final score = c.overallScore;
  var ranking = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.candidateName ?? c.fileName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(c.fileName, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 16),
                  if (onRank != null && c.status != 'failed') ...[
                    _RankCvButton(
                      label: score == null ? 'Rank this CV' : 'Re-rank CV',
                      busy: ranking,
                      onPressed: () async {
                        setState(() => ranking = true);
                        try {
                          await onRank();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => ranking = false);
                          }
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
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(score * 100).round()}%',
                          style: theme.textTheme.titleMedium?.copyWith(
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
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          formatBucket(c.bucket ?? 'weak_match'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: getBucketColor(c.bucket ?? 'weak_match'),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (c.rankedBy != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ranked by',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _rankedByLabel(c.rankedBy!),
                            style: theme.textTheme.titleMedium,
                          ),
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
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          c.status.isEmpty ? 'uploaded' : c.status,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (c.status == 'failed' && c.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Error',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(c.error!, style: theme.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This candidate has not been ranked yet.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.skills.isNotEmpty) ...[
                    const CandidateSectionLabel(
                      icon: Icons.bolt,
                      label: 'SKILLS',
                      color: Colors.indigo,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.skills
                          .map(
                            (skill) => Chip(
                              label: Text(skill),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.indigo.shade50,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.indigo.shade700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.yearsExperience != null && c.yearsExperience! > 0) ...[
                    const CandidateSectionLabel(
                      icon: Icons.work_history,
                      label: 'EXPERIENCE',
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatYears(c.yearsExperience!),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.education != null && c.education!.isNotEmpty) ...[
                    const CandidateSectionLabel(
                      icon: Icons.school,
                      label: 'EDUCATION',
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 8),
                    Text(c.education!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],
                  if (c.certifications.isNotEmpty) ...[
                    const CandidateSectionLabel(
                      icon: Icons.workspace_premium,
                      label: 'CERTIFICATIONS',
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.certifications
                          .map(
                            (cert) => Chip(
                              label: Text(cert),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.deepPurple.shade50,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.deepPurple.shade700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.strengths.isNotEmpty) ...[
                    const CandidateSectionLabel(
                      icon: Icons.check_circle,
                      label: 'STRENGTHS',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.strengths
                          .map(
                            (skill) => Chip(
                              label: Text(skill),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.green.shade50,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.skillGaps.isNotEmpty) ...[
                    const CandidateSectionLabel(
                      icon: Icons.warning,
                      label: 'MISSING SKILLS',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.skillGaps
                          .map(
                            (gap) => Chip(
                              label: Text(gap),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.red.shade50,
                              labelStyle: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red.shade700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.recommendation != null) ...[
                    Text(
                      'Recommendation',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(c.recommendation!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  if (c.explanation != null) ...[
                    Text(
                      'Explanation',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(c.explanation!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  if (c.weaknesses.isNotEmpty)
                    CandidateBulletList(
                      title: 'Areas to probe',
                      items: c.weaknesses,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _rankedByLabel(String source) {
  return source == 'llm' ? 'AI' : 'In-App';
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
