import 'package:flutter/material.dart';

import '../../ranking/domain/ranking_models.dart';

class RankingList extends StatelessWidget {
  const RankingList({super.key, required this.results});

  final List<RankedCandidate> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('No candidates matched your query.'));
    }
    final buckets = {
      RankingBucket.best: results.where((r) => r.bucket == RankingBucket.best).toList(),
      RankingBucket.strong: results.where((r) => r.bucket == RankingBucket.strong).toList(),
      RankingBucket.hiddenGem: results.where((r) => r.bucket == RankingBucket.hiddenGem).toList(),
      RankingBucket.alternative: results.where((r) => r.bucket == RankingBucket.alternative).toList(),
    };

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Best'),
              Tab(text: 'Strong'),
              Tab(text: 'Hidden Gems'),
              Tab(text: 'Alternatives'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BucketView(label: 'Best Match', items: buckets[RankingBucket.best]!),
                _BucketView(label: 'Strong Match', items: buckets[RankingBucket.strong]!),
                _BucketView(label: 'Hidden Gems', items: buckets[RankingBucket.hiddenGem]!),
                _BucketView(label: 'Alternatives', items: buckets[RankingBucket.alternative]!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketView extends StatelessWidget {
  const _BucketView({required this.label, required this.items});

  final String label;
  final List<RankedCandidate> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No candidates in this bucket.'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _RankCard(candidate: items[index]),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.candidate});

  final RankedCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        leading: _ScoreGauge(score: candidate.overallScore),
        title: Text(candidate.candidateName, style: theme.textTheme.titleMedium),
        subtitle: Text(
          'Skill ${(candidate.scores.skillMatch * 100).round()} · '
          'Exp ${(candidate.scores.experienceMatch * 100).round()}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(candidate.explanation, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (final chunk in candidate.evidence.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• [${chunk.section}] ${chunk.text}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 0.8
        ? Colors.green
        : score >= 0.6
            ? Colors.orange
            : Colors.grey;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: score, color: color, backgroundColor: color.withValues(alpha: 0.2)),
          Text('${(score * 100).round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
