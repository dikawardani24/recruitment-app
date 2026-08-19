import 'package:flutter/material.dart';

import '../../widgets/card_shape.dart';
import '../models/help_item.dart';
import 'help_category_content.dart';

/// An expandable card for a Help & Guidance category. Tapping the header
/// reveals the category's guidance sections and FAQ items in place instead of
/// navigating to a separate page.
class HelpCategoryExpandable extends StatelessWidget {
  final HelpCategory category;

  const HelpCategoryExpandable({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(category.icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(
          category.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(category.subtitle, style: theme.textTheme.bodySmall),
        children: [HelpCategoryContent(category: category)],
      ),
    );
  }
}