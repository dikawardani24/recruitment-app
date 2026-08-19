import 'package:flutter/material.dart';

/// The ranking engines a candidate can be scored by. Shown to the user when
/// they tap a "Ranked by" chip/row so they understand what the value means,
/// what the alternatives are, and how to enable AI ranking.
enum RankingEngine {
  inApp(
    'In-App',
    Icons.functions,
    Colors.blueGrey,
    'The built-in, deterministic rule-based engine. Runs entirely inside the '
        'app — no API key or internet needed. Always available and reproducible.',
  ),
  ai(
    'AI',
    Icons.auto_awesome,
    Colors.deepPurple,
    'LLM-powered ranking via your configured AI provider (Gemini or '
        'OpenRouter). Used automatically when a working API key is set. Scores '
        'may vary between runs.',
  );

  const RankingEngine(this.label, this.icon, this.color, this.description);

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  static RankingEngine fromSource(String? source) =>
      source == 'llm' ? RankingEngine.ai : RankingEngine.inApp;
}

/// Shows the label/color/icon used for a given ranked-by source value.
String rankedByLabel(String? source) => RankingEngine.fromSource(source).label;

Color rankedByColor(String? source) => RankingEngine.fromSource(source).color;

/// Opens the explainer dialog for the current ranked-by value.
void showRankedByInfoDialog(BuildContext context, {String? currentRankedBy}) {
  showDialog<void>(
    context: context,
    builder: (_) => RankedByInfoDialog(currentRankedBy: currentRankedBy),
  );
}

/// Tappable "Ranked by `<engine>`" row used on the candidate detail screen.
/// Tapping opens [showRankedByInfoDialog].
class RankedByInfoRow extends StatelessWidget {
  final String? rankedBy;

  const RankedByInfoRow({super.key, this.rankedBy});

  @override
  Widget build(BuildContext context) {
    final engine = RankingEngine.fromSource(rankedBy);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => showRankedByInfoDialog(context, currentRankedBy: rankedBy),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              engine.icon,
              size: 16,
              color: engine.color,
            ),
            const SizedBox(width: 6),
            Text(
              engine.label,
              style: theme.textTheme.titleMedium?.copyWith(color: engine.color),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class RankedByInfoDialog extends StatelessWidget {
  final String? currentRankedBy;

  const RankedByInfoDialog({super.key, this.currentRankedBy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = RankingEngine.fromSource(currentRankedBy);

    return AlertDialog(
      icon: const Icon(Icons.psychology, size: 32),
      title: const Text('Ranked by'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Which engine produced this candidate\u2019s match score.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CurrentEngineCard(engine: current),
            const SizedBox(height: 20),
            Text('Ranking engines', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final engine in RankingEngine.values) ...[
              _EngineTile(engine: engine, highlighted: engine == current),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Text('How to get AI ranking', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              '1. Open Settings → API Key Configuration.\n'
              '2. Add a Gemini or OpenRouter API key.\n'
              '3. Tap Rank for the job (or candidate) again.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'AI ranking is optional. If it is unavailable (for example, the '
              'API quota is exceeded), the app automatically falls back to '
              'In-App ranking.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _CurrentEngineCard extends StatelessWidget {
  final RankingEngine engine;

  const _CurrentEngineCard({required this.engine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: engine.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: engine.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(engine.icon, color: engine.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This candidate was ranked by',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  engine.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: engine.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineTile extends StatelessWidget {
  final RankingEngine engine;
  final bool highlighted;

  const _EngineTile({required this.engine, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(engine.icon, size: 18, color: engine.color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    engine.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (highlighted) ...[
                    const SizedBox(width: 6),
                    Text(
                      'current',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(engine.description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}