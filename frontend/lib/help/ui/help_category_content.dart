import 'package:flutter/material.dart';

import '../../widgets/section_card.dart';
import '../models/help_item.dart';
import 'faq_item.dart';

/// Renders all guidance sections and FAQ groups of a [HelpCategory] in a
/// column. Used as the expanded body of the category cards on the help page.
class HelpCategoryContent extends StatelessWidget {
  final HelpCategory category;

  const HelpCategoryContent({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[
      for (final section in category.sections) _SectionCard(section: section),
      for (final group in category.faqGroups) _FaqGroupCard(group: group),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          blocks[i],
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final HelpSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: section.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < section.body.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _HelpBlockView(block: section.body[i]),
          ],
        ],
      ),
    );
  }
}

class _FaqGroupCard extends StatelessWidget {
  final FaqGroup group;

  const _FaqGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: group.title,
      child: Column(
        children: [
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            FaqItem(entry: group.items[i]),
          ],
        ],
      ),
    );
  }
}

/// Renders one [HelpBlock] using the app's theme and existing components.
class _HelpBlockView extends StatelessWidget {
  final HelpBlock block;

  const _HelpBlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (block) {
      HelpParagraph(:final text) => Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      HelpBulletList(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      HelpSteps(:final steps) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          steps[i],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      HelpCallout(:final text) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      HelpExample(:final rows) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in rows.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${entry.key} ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: entry.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
    };
  }
}