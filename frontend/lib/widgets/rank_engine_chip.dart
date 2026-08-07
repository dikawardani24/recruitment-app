import 'package:flutter/material.dart';

/// Small floating chip showing which ranking engine scored a candidate
/// ('llm' = AI, otherwise the deterministic rule-based engine). Renders
/// nothing when [rankedBy] is null/empty (e.g. not ranked yet).
class RankEngineChip extends StatelessWidget {
  final String? rankedBy;

  const RankEngineChip({super.key, this.rankedBy});

  @override
  Widget build(BuildContext context) {
    final by = rankedBy;
    if (by == null || by.isEmpty) return const SizedBox.shrink();
    final isLlm = by == 'llm';
    final color = isLlm ? Colors.deepPurple : Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLlm ? Icons.auto_awesome : Icons.functions,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isLlm ? 'AI' : 'In-App',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
