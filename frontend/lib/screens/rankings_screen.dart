import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

class RankingsScreen extends StatefulWidget {
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
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  late Future<List<CandidateResult>> _rankings;

  @override
  void initState() {
    super.initState();
    _rankings = ApiClient.instance.getRankings(widget.jobId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ranked candidates'),
            Text(
              widget.jobTitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<CandidateResult>>(
        future: _rankings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return const Center(child: Text('No candidates ranked yet.'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Chip(
                  avatar: const Icon(Icons.psychology, size: 18),
                  label: Text(
                    'Ranking by ${widget.source == 'llm' ? 'AI (LLM)' : 'rule-based engine'}',
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _RankedCard(
                      candidate: results[index],
                      rank: index + 1,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankedCard extends StatefulWidget {
  final CandidateResult candidate;
  final int rank;

  const _RankedCard({required this.candidate, required this.rank});

  @override
  State<_RankedCard> createState() => _RankedCardState();
}

class _RankedCardState extends State<_RankedCard> {
  bool _expanded = false;

  Color get _scoreColor {
    final score = widget.candidate.overallScore ?? 0;
    if (score >= 0.85) return Colors.green;
    if (score >= 0.7) return Colors.lightGreen.shade700;
    if (score >= 0.5) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.candidate;
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
                  backgroundColor: _scoreColor,
                  child: Text('${widget.rank}',
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
                        ?.copyWith(color: _scoreColor),
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
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? 'Hide reasoning' : 'Show reasoning'),
                ),
              ),
            if (_expanded) ...[
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
