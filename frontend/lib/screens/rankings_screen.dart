import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models.dart';
import '../providers.dart';
import '../widgets/rankings_summary.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ranked candidates'),
            Text(
              jobTitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
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

class _RankedCard extends HookWidget {
  final CandidateResult candidate;
  final int rank;

  const _RankedCard({required this.candidate, required this.rank});

  @override
  Widget build(BuildContext context) {
    final expanded = useState(false);
    final c = candidate;
    final name = c.candidateName ?? c.fileName;
    final score = c.overallScore;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorForScore(score ?? 0),
                  child: Text('$rank',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(c.fileName,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (score != null)
                  Text(
                    '${(score * 100).round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: colorForScore(score)),
                  ),
              ],
            ),
            if (c.recommendation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  c.recommendation!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (c.explanation != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(c.explanation!),
              ),
            if (c.skillGaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: c.skillGaps
                    .map((gap) => Chip(
                          label: Text('missing: $gap'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.red.shade50,
                        ))
                    .toList(),
              ),
            ],
            if (c.strengths.isNotEmpty || c.weaknesses.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => expanded.value = !expanded.value,
                  icon: Icon(expanded.value
                      ? Icons.expand_less
                      : Icons.expand_more),
                  label: Text(
                      expanded.value ? 'Hide reasoning' : 'Show reasoning'),
                ),
              ),
            if (expanded.value) ...[
              if (c.strengths.isNotEmpty)
                _BulletList(title: 'Strengths', items: c.strengths),
              if (c.weaknesses.isNotEmpty)
                _BulletList(title: 'Areas to probe', items: c.weaknesses),
            ],
          ],
        ),
      ),
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
