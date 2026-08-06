import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/gradient_header.dart';
import '../widgets/rankings_summary.dart';
import '../widgets/score_color.dart';

class RankingsScreen extends HookConsumerWidget {
  final String jobId;
  final String jobTitle;
  final String source;

  const RankingsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.source,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(rankingsProvider(jobId));

    return Scaffold(
      appBar: AppBar(),
      body: rankingsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading rankings…'),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('$e')),
        data: (results) {
          if (results.isEmpty) {
            return const Center(child: Text('No candidates ranked yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: results.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    GradientHeader(
                      icon: Icons.psychology,
                      title: 'Ranked candidates',
                      subtitle: jobTitle,
                    ),
                    const SizedBox(height: 12),
                    Chip(
                      avatar: const Icon(Icons.psychology, size: 18),
                      label: Text(
                        'Ranking by ${source == 'llm' ? 'AI (LLM)' : 'rule-based engine'}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    RankingsSummary(results: results),
                  ],
                );
              }
              return _RankedCard(
                candidate: results[index - 1],
                rank: index,
              );
            },
          );
        },
      ),
    );
  }
}

class _RankedCard extends StatelessWidget {
  final CandidateResult candidate;
  final int rank;

  const _RankedCard({required this.candidate, required this.rank});

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final name = c.candidateName ?? c.fileName;
    final score = c.overallScore;
    final color = scoreColor(score ?? 0);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Text('$rank',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: theme.textTheme.titleMedium),
                      Text(c.fileName,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (score != null) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(score * 100).round()}%',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: color),
                      ),
                      Text(
                        'Match Score',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (c.strengths.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.check_circle,
                label: 'STRENGTHS',
                color: Colors.green,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: c.strengths
                    .map((skill) => Chip(
                          label: Text(skill),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.green.shade50,
                          labelStyle: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green.shade700),
                        ))
                    .toList(),
              ),
            ],
            if (c.skillGaps.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.warning,
                label: 'MISSING SKILLS',
                color: Colors.red,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: c.skillGaps
                    .map((gap) => Chip(
                          label: Text(gap),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.red.shade50,
                          labelStyle: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.red.shade700),
                        ))
                    .toList(),
              ),
            ],
            if (c.recommendation != null ||
                c.explanation != null ||
                c.weaknesses.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showReasoningDialog(context, c, theme),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Show reasoning'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReasoningDialog(
      BuildContext context, CandidateResult c, ThemeData theme) {
    final score = c.overallScore;
    final color = scoreColor(score ?? 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.candidateName ?? c.fileName,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(c.fileName,
                      style: theme.textTheme.labelSmall),
                  const SizedBox(height: 16),
                  if (score != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Match Score',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${(score * 100).round()}%',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.strengths.isNotEmpty) ...[
                    _SectionLabel(
                      icon: Icons.check_circle,
                      label: 'STRENGTHS',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.strengths
                          .map((skill) => Chip(
                                label: Text(skill),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.green.shade50,
                                labelStyle: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.green.shade700),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.skillGaps.isNotEmpty) ...[
                    _SectionLabel(
                      icon: Icons.warning,
                      label: 'MISSING SKILLS',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: c.skillGaps
                          .map((gap) => Chip(
                                label: Text(gap),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.red.shade50,
                                labelStyle: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.red.shade700),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (c.recommendation != null) ...[
                    Text('Recommendation',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(c.recommendation!,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  if (c.explanation != null) ...[
                    Text('Explanation',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(c.explanation!,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  if (c.weaknesses.isNotEmpty)
                    _BulletList(title: 'Areas to probe', items: c.weaknesses),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
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
          style: theme.textTheme.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletList({required this.title, required this.items});

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
