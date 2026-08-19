import 'package:flutter/material.dart';

import '../../widgets/deferred_page.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/section_card.dart';
import '../data/help_content.dart';
import '../models/help_item.dart';
import 'faq_item.dart';

/// Detail view for one Help & Guidance category: its guidance sections and
/// its expandable FAQ items.
class HelpCategoryPage extends StatelessWidget {
  final String categoryId;

  const HelpCategoryPage({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final category = helpCategoryById(categoryId);
    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Category not found.')),
      );
    }
    return DeferredPage(
      child: _HelpCategoryContent(category: category),
    );
  }
}

class _HelpCategoryContent extends StatelessWidget {
  final HelpCategory category;

  const _HelpCategoryContent({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          GradientHeader(
            icon: category.icon,
            title: category.title,
            subtitle: category.subtitle,
          ),
          for (final section in category.sections) ...[
            const SizedBox(height: 12),
            _SectionCard(section: section),
          ],
          for (final group in category.faqGroups) ...[
            const SizedBox(height: 12),
            _FaqGroupCard(group: group),
          ],
        ],
      ),
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