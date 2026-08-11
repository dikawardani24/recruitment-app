import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/candidate_search_controller.dart';
import '../controllers/job_list_controller.dart';
import '../providers.dart';
import '../widgets/card_shape.dart';
import '../widgets/candidate_tile.dart';
import '../widgets/deferred_page.dart';
import '../widgets/error_view.dart';
import '../widgets/job_card.dart';
import '../widgets/section_card.dart';

class UnifiedSearchScreen extends StatelessWidget {
  const UnifiedSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _UnifiedSearchContent());
  }
}

class _UnifiedSearchContent extends HookConsumerWidget {
  const _UnifiedSearchContent();

  static const _debounceDelay = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchController = useTextEditingController();
    final debounce = useRef<Timer?>(null);
    final keyword = useState('');

    final searchAsync = ref.watch(unifiedSearchProvider(keyword.value));
    final searchHistory = ref.watch(searchHistoryProvider);
    
    final jobListController = ref.read(jobListControllerProvider);
    final candidateSearchController = ref.read(candidateSearchControllerProvider);

    useEffect(() {
      return () => debounce.value?.cancel();
    }, [debounce]);

    void runSearch(String value) {
      keyword.value = value.trim();
      if (keyword.value.isNotEmpty) {
        ref.read(searchHistoryProvider.notifier).add(keyword.value);
      }
    }

    void onChanged(String value) {
      debounce.value?.cancel();
      debounce.value = Timer(_debounceDelay, () => runSearch(value));
    }

    void onSubmitted(String value) {
      debounce.value?.cancel();
      runSearch(value);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => ref.read(navigatorProvider).pop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: 'Search jobs or candidates',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchController,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear',
                    onPressed: () {
                      searchController.clear();
                      onSubmitted('');
                    },
                  ),
          ),
        ],
      ),
      body: searchAsync.when(
        loading: () => const _SearchLoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.read(unifiedSearchProvider(keyword.value).notifier).refresh(),
        ),
        data: (result) {
          final showHistory = keyword.value.isEmpty && searchHistory.isNotEmpty;
          if (result.isEmpty && !showHistory && keyword.value.isNotEmpty) {
            return _NoResultsView(keyword: keyword.value);
          }
          if (keyword.value.isEmpty && !showHistory) {
            return const _EmptyStateView();
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(unifiedSearchProvider(keyword.value).notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (showHistory)
                  _SearchHistoryCard(
                    keywords: searchHistory,
                    onSelect: (kw) {
                      searchController.text = kw;
                      runSearch(kw);
                    },
                  ),
                if (result.jobs.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Jobs',
                    onViewAll: result.jobsHasMore
                        ? () => ref.read(navigatorProvider).goToSearchJobs()
                        : null,
                  ),
                  for (final entry in result.jobs.asMap().entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(
                        job: entry.value,
                        index: entry.key,
                        onTap: () => jobListController.openJobDetail(entry.value.id),
                      ),
                    ),
                ],
                if (result.candidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionHeader(
                    title: 'Candidates',
                    onViewAll: result.candidatesHasMore
                        ? () => ref.read(navigatorProvider).goToSearchCandidates()
                        : null,
                  ),
                  for (final cv in result.candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CandidateTile(
                        cv: cv,
                        onShowDetails: () => candidateSearchController.openCandidateDetails(cv),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              child: const Text('View all'),
            ),
        ],
      ),
    );
  }
}

class _SearchLoadingView extends StatelessWidget {
  const _SearchLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const _SkeletonHeader(),
        for (var i = 0; i < 2; i++) const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: JobCardSkeleton(),
        ),
        const SizedBox(height: 12),
        const _SkeletonHeader(),
        for (var i = 0; i < 3; i++) const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: CandidateTileSkeleton(),
        ),
      ],
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 20,
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SearchHistoryCard extends StatelessWidget {
  const _SearchHistoryCard({required this.keywords, required this.onSelect});

  final List<String> keywords;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape(theme),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Text(
                'Recent searches',
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final kw in keywords)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.history,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(kw, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onSelect(kw),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Search your workspace',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Find jobs or candidates by name, title, or skills.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final String keyword;

  const _NoResultsView({required this.keyword});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('No results found', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Nothing matches "$keyword". Try a different search term.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
