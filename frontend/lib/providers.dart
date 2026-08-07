import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';
import 'models.dart';
import 'navigation/app_navigator.dart';
import 'navigation/go_router_navigator.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

/// Paginated job list state. [jobs] accumulates across pages as the user
/// scrolls; [hasMore] indicates whether another page is available.
class JobListState {
  final List<Job> jobs;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  const JobListState({
    this.jobs = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  JobListState copyWith({
    List<Job>? jobs,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return JobListState(
      jobs: jobs ?? this.jobs,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class JobListNotifier extends AsyncNotifier<JobListState> {
  static const int pageSize = 20;

  /// Minimum time the shimmer skeleton stays visible on initial load, so the
  /// list never flashes in faster than the eye can register.
  static const Duration minLoadDuration = Duration(seconds: 1);

  @override
  Future<JobListState> build() => _loadFirstPage();

  Future<JobListState> _loadFirstPage() async {
    final results = await Future.wait([
      ref.read(apiClientProvider).listJobs(page: 1),
      Future<void>.delayed(minLoadDuration),
    ]);
    final page = results.first as JobPage;
    return JobListState(
      jobs: page.jobs,
      page: 1,
      hasMore: page.hasMore,
    );
  }

  /// Fetches the next page and appends it to [JobListState.jobs]. No-op while
  /// a page is already loading or when there is nothing left to load.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(apiClientProvider)
          .listJobs(page: current.page + 1);
      state = AsyncValue.data(
        current.copyWith(
          jobs: [...current.jobs, ...next.jobs],
          page: next.page,
          hasMore: next.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Reloads from page 1, dropping any previously loaded pages. The loading
  /// state is set explicitly so the shimmer is always shown while refreshing.
  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      state = AsyncValue.data(await _loadFirstPage());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final jobsProvider =
    AsyncNotifierProvider<JobListNotifier, JobListState>(JobListNotifier.new);

final jobProvider = FutureProvider.family<Job, String>((ref, jobId) {
  return ref.read(apiClientProvider).getJob(jobId);
});

final cvsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).listCvs(jobId);
});

final rankingsProvider = FutureProvider.family<List<CandidateResult>, String>((ref, jobId) {
  return ref.read(apiClientProvider).getRankings(jobId);
});

/// The app's single [GoRouter] instance. Overridden in `main()` so the same
/// instance is shared by the widget tree and [navigatorProvider].
final goRouterProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError('goRouterProvider must be overridden'),
);

/// [AppNavigator] implementation exposed to the widget tree. Screens and
/// controllers read this provider and never touch go_router directly.
final navigatorProvider = Provider<AppNavigator>(
  (ref) => GoRouterNavigator(ref.watch(goRouterProvider)),
);
