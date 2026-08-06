import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';

const _bucketOrder = [
  'strong_match',
  'good_match',
  'possible_match',
  'weak_match',
];
const _bucketLabels = {
  'strong_match': 'Strong',
  'good_match': 'Good',
  'possible_match': 'Possible',
  'weak_match': 'Weak',
};
const _bucketColors = {
  'strong_match': Colors.green,
  'good_match': Colors.lightGreen,
  'possible_match': Colors.orange,
  'weak_match': Colors.redAccent,
};

/// Counts ranked results per recommendation bucket, in canonical order,
/// omitting buckets with no candidates.
Map<String, int> bucketCounts(List<CandidateResult> results) {
  final counts = <String, int>{};
  for (final r in results) {
    final bucket = r.bucket ?? 'weak_match';
    counts[bucket] = (counts[bucket] ?? 0) + 1;
  }
  return {
    for (final bucket in _bucketOrder)
      if ((counts[bucket] ?? 0) > 0) bucket: counts[bucket]!,
  };
}

/// A card showing the distribution of ranked candidates across
/// recommendation buckets as a donut chart with a legend.
class BucketDonut extends StatelessWidget {
  final Map<String, int> buckets;

  const BucketDonut({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = buckets.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = buckets.values.fold<int>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.donut_large,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buckets',
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$total candidates',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        for (final e in entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            color: _bucketColors[e.key],
                            radius: 40,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$total',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _bucketColors[e.key],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _bucketLabels[e.key] ?? e.key,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
