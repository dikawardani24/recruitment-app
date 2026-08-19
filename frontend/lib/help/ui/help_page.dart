import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../navigation/app_navigator.dart';
import '../../providers.dart';
import '../../widgets/deferred_page.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/section_card.dart';
import '../data/help_content.dart';
import '../models/help_item.dart';
import 'faq_item.dart';
import 'help_category_card.dart';

/// Help & Guidance home: a search field plus all categories. Search filters
/// the static content locally and returns matching categories + FAQ entries.
class HelpPage extends HookConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigator = ref.read(navigatorProvider);
    final query = useState('');
    final trimmed = query.value.trim();
    final results = searchHelp(trimmed);

    return DeferredPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Help & Guidance')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                onChanged: (value) => query.value = value,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search help',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: trimmed.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () => query.value = '',
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: trimmed.isEmpty
                  ? _HelpHome(navigator: navigator)
                  : _SearchResults(
                      query: trimmed,
                      results: results,
                      navigator: navigator,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpHome extends StatelessWidget {
  final AppNavigator navigator;

  const _HelpHome({required this.navigator});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        const GradientHeader(
          icon: Icons.help_outline,
          title: 'Help & Guidance',
          subtitle: 'How can we help?',
        ),
        const SizedBox(height: 16),
        for (final category in helpCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HelpCategoryCard(
              category: category,
              onTap: () => navigator.goToHelpCategory(category.id),
            ),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final HelpSearchResults results;
  final AppNavigator navigator;

  const _SearchResults({
    required this.query,
    required this.results,
    required this.navigator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No results for "$query". Try another keyword.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text('Search results', style: theme.textTheme.titleMedium),
        if (results.categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final category in results.categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HelpCategoryCard(
                category: category,
                onTap: () => navigator.goToHelpCategory(category.id),
              ),
            ),
        ],
        if (results.faqHits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('FAQ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Matching questions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < results.faqHits.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                    ),
                    child: Text(
                      results.faqHits[i].category.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  FaqItem(entry: results.faqHits[i].entry),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}