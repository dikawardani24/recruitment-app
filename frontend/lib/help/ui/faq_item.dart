import 'package:flutter/material.dart';

import '../models/help_item.dart';

/// One expandable FAQ question/answer row. The answer is collapsed until the
/// question is tapped.
class FaqItem extends StatelessWidget {
  final FaqEntry entry;

  const FaqItem({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: theme.colorScheme.primary,
      collapsedIconColor: theme.colorScheme.primary,
      leading: const Icon(Icons.help_outline, size: 20),
      title: Text(
        entry.question,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            entry.answer,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}