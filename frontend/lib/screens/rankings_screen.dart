import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/models.dart';
import '../providers.dart';
import '../widgets/candidate_detail_sheet.dart';
import '../widgets/gradient_header.dart';
import '../widgets/rank_engine_chip.dart';
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
                    RankingsSummary(results: results),
                  ],
                );
              }
              return _RankedCard(candidate: results[index - 1], rank: index);
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
                  child: Text(
                    '$rank',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      Text(c.fileName, style: theme.textTheme.bodySmall),
                      if (c.rankedBy != null) ...[
                        const SizedBox(height: 6),
                        RankEngineChip(rankedBy: c.rankedBy),
                      ],
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: color,
                        ),
                      ),
                      Text('Match Score', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ],
              ],
            ),
            if (c.strengths.isNotEmpty) ...[
              const SizedBox(height: 12),
              CandidateSectionLabel(
                icon: Icons.check_circle,
                label: 'STRENGTHS',
                color: Colors.green,
              ),
              const SizedBox(height: 6),
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
            ],
            if (c.skillGaps.isNotEmpty) ...[
              const SizedBox(height: 12),
              CandidateSectionLabel(
                icon: Icons.warning,
                label: 'MISSING SKILLS',
                color: Colors.red,
              ),
              const SizedBox(height: 6),
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
            ],
            if (c.recommendation != null ||
                c.explanation != null ||
                c.weaknesses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showCandidateDetailSheet(context, c),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Show reasoning'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
