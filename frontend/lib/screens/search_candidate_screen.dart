import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/candidate_search_controller.dart';
import '../providers.dart';
import '../widgets/card_shape.dart';
import '../widgets/candidate_tile.dart';
import '../widgets/delete_background.dart';
import '../widgets/deferred_page.dart';
import '../widgets/error_view.dart';
import '../widgets/job_list_footer.dart';

/// Full-page candidate search. Type a keyword and press enter (or let the
/// debounce fire) to query the backend. Results load with shimmer placeholders
/// and paginate as the user scrolls. When the input is empty, a card lists the
/// recent in-memory searches for quick re-runs.
class SearchCandidateScreen extends StatelessWidget {
  const SearchCandidateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DeferredPage(child: _SearchCandidateContent());
  }
}

class _SearchCandidateContent extends HookConsumerWidget {
  const _SearchCandidateContent();

  static const _loadMoreThreshold = 300.0;
  static const _debounceDelay = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final searchController = useTextEditingController();
    final scrollController = useScrollController();
    final debounce = useRef<Timer?>(null);
    final keyword = useState('');

    final searchAsync = ref.watch(searchCandidatesProvider(keyword.value));
    final searchHistory = ref.watch(candidateSearchHistoryProvider);
    final candidateSearchController = ref.read(candidateSearchControllerProvider);

    useEffect(() {
      return () => debounce.value?.cancel();
    }, [debounce]);

    void runSearch(String value) {
      keyword.value = value.trim();
      if (keyword.value.isNotEmpty) {
        ref.read(candidateSearchHistoryProvider.notifier).add(keyword.value);
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
          ref.read(searchCandidatesProvider(keyword.value).notifier).loadMore();
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
              hintText: 'Search candidates',
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
          itemBuilder: (_, _) => const CandidateTileSkeleton(),
        ),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref
              .read(searchCandidatesProvider(keyword.value).notifier)
              .refresh(),
        ),
        data: (state) {
          final candidates = state.candidates;
          final showHistory = keyword.value.isEmpty && searchHistory.isNotEmpty;
          if (candidates.isEmpty && !showHistory) {
            return _NoResultsView(keyword: keyword.value);
          }
          return RefreshIndicator(
            onRefresh: () => ref
                .read(searchCandidatesProvider(keyword.value).notifier)
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
                if (candidates.isEmpty && showHistory)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No candidates match your search.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                for (final cv in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('search-cv-${cv.cvId}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final deleted = await candidateSearchController.deleteCandidate(cv);
                        if (deleted) {
                          await ref
                              .read(searchCandidatesProvider(keyword.value).notifier)
                              .refresh();
                        }
                        return deleted;
                      },
                      background: DeleteBackground(
                        color: theme.colorScheme.error,
                      ),
                      child: CandidateTile(
                        cv: cv,
                        onShowDetails: () => candidateSearchController.openCandidateDetails(cv),
                      ),
                    ),
                  ),
                if (candidates.isNotEmpty) _CandidateListFooter(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CandidateListFooter extends StatelessWidget {
  final CandidateListState state;

  const _CandidateListFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.hasMore && state.candidates.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No more candidates.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return const SizedBox.shrink();
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
            Text('No candidates found', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              keyword.isEmpty
                  ? 'Start searching for candidates across all jobs.'
                  : 'No candidates match "$keyword".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
