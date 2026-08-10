import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_list_controller.dart';
import '../providers.dart';
import '../widgets/card_shape.dart';
import '../widgets/delete_background.dart';
import '../widgets/error_view.dart';
import '../widgets/job_card.dart';
import '../widgets/job_list_footer.dart';

/// Full-page job search. Type a keyword and press enter (or let the debounce
/// fire) to query the backend; an empty keyword returns every job. Results load
/// with shimmer placeholders and paginate as the user scrolls. When the input
/// is empty, a card lists the recent in-memory searches for quick re-runs.
class SearchJobScreen extends HookConsumerWidget {
  const SearchJobScreen({super.key});

  static const _loadMoreThreshold = 300.0;
  static const _debounceDelay = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchController = useTextEditingController();
    final scrollController = useScrollController();
    final debounce = useRef<Timer?>(null);
    final keyword = useState('');

    final searchAsync = ref.watch(searchJobsProvider(keyword.value));
    final searchHistory = ref.watch(searchHistoryProvider);
    final jobListController = ref.read(jobListControllerProvider);

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

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        if (position.maxScrollExtent > 0 &&
            position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
          ref.read(searchJobsProvider(keyword.value).notifier).loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController, keyword.value]);

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
              hintText: 'Search jobs',
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
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const JobCardSkeleton(),
        ),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref
              .read(searchJobsProvider(keyword.value).notifier)
              .refresh(),
        ),
        data: (state) {
          final jobs = state.jobs;
          final showHistory = keyword.value.isEmpty && searchHistory.isNotEmpty;
          if (jobs.isEmpty && !showHistory) {
            return _NoResultsView(keyword: keyword.value);
          }
          return RefreshIndicator(
            onRefresh: () => ref
                .read(searchJobsProvider(keyword.value).notifier)
                .refresh(),
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
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
                if (jobs.isEmpty && showHistory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No jobs yet. Create your first job.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                for (final entry in jobs.asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('search-job-${entry.value.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final deleted = await jobListController.deleteJob(
                          entry.value,
                        );
                        if (deleted) {
                          await ref
                              .read(searchJobsProvider(keyword.value).notifier)
                              .refresh();
                        }
                        return deleted;
                      },
                      background: DeleteBackground(
                        color: theme.colorScheme.error,
                      ),
                      child: JobCard(
                        job: entry.value,
                        index: entry.key,
                        onTap: () =>
                            jobListController.openJobDetail(entry.value.id),
                      ),
                    ),
                  ),
                if (jobs.isNotEmpty) JobListFooter(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card shown under the search input while it is empty, listing the recent
/// searches recorded this session. Tapping one re-runs that search.
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
            Text('No jobs found', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              keyword.isEmpty
                  ? 'No jobs yet. Create your first job.'
                  : 'No jobs match "$keyword".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
