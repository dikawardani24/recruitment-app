import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import 'bucket_donut.dart';
import 'score_color.dart';

class RankingsSummary extends StatelessWidget {
  const RankingsSummary({super.key, required this.results});

  final List<CandidateResult> results;

  @override
  Widget build(BuildContext context) {
    final scored = results.where((r) => r.overallScore != null).toList();
    if (scored.isEmpty) return const SizedBox.shrink();

    final sorted = [...scored]
      ..sort((a, b) => b.overallScore!.compareTo(a.overallScore!));
    final top = sorted.take(10).toList();
    final buckets = bucketCounts(scored);
    final missing = _topMissingSkills(scored);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreBars(results: top),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final donut = BucketDonut(buckets: buckets);
                final skills = _MissingSkills(skills: missing);
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      donut,
                      const SizedBox(height: 12),
                      skills,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: donut),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: skills),
                  ],
                );
              },
            ),
          )
        else if (buckets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: BucketDonut(buckets: buckets),
          ),
      ],
    );
  }

  static List<MapEntry<String, int>> _topMissingSkills(
    List<CandidateResult> scored,
  ) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final r in scored) {
      for (final gap in r.skillGaps) {
        final key = gap.trim().toLowerCase();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
        display[key] = gap.trim();
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => MapEntry(display[e.key]!, e.value)).toList();
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScoreBars extends StatelessWidget {
  const _ScoreBars({required this.results});

  final List<CandidateResult> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.bar_chart,
              title: 'Score overview',
              subtitle:
                  'Top ${results.length} candidates by overall score',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1,
                  minY: 0,
                  barTouchData: BarTouchData(enabled: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 0.25,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${(value * 100).round()}%',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${value.round() + 1}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < results.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: results[i].overallScore!,
                            width: 16,
                            color: scoreColor(results[i].overallScore!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingSkills extends StatelessWidget {
  const _MissingSkills({required this.skills});

  final List<MapEntry<String, int>> skills;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = skills.first.value.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.rule,
              title: 'Missing skills',
              subtitle: 'Most common gaps across candidates',
            ),
            const SizedBox(height: 8),
            for (final e in skills)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${e.value}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: e.value / maxCount,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
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
