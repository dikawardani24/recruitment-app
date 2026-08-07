import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_list_controller.dart';
import '../domain/models.dart';
import '../providers.dart';
import '../widgets/gradient_header.dart';
import '../widgets/shimmer.dart';
import 'action_result_screen.dart';
import 'delete_confirm_screen.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats an ISO-8601 UTC timestamp as `dd MMM yyyy h:mm am/pm` in local time.
String formatCreatedAt(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return '';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _months[local.month - 1];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  return '$day $month ${local.year} $hour12:$minute $period';
}

class JobListScreen extends HookConsumerWidget {
  const JobListScreen({super.key});

  static const _loadMoreThreshold = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final jobListController = ref.read(jobListControllerProvider);
    final scrollController = useScrollController();

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        if (position.maxScrollExtent > 0 &&
            position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
          jobListController.loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          ChuckerFlutter.chuckerButton,
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(navigatorProvider).goToJobForm(),
        icon: const Icon(Icons.add),
        label: const Text('New job'),
      ),
      body: jobsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const _JobCardSkeleton(),
        ),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: jobListController.refresh,
        ),
        data: (state) {
          final jobs = state.jobs;
          if (jobs.isEmpty) return const _EmptyView();
          final theme = Theme.of(context);
          final totalCandidates = jobs.fold<int>(
            0,
            (sum, j) => sum + j.candidateCount,
          );
          return RefreshIndicator(
            onRefresh: jobListController.refresh,
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                GradientHeader(
                  icon: Icons.work,
                  title: 'Your job board',
                  subtitle: '$totalCandidates candidates · ${jobs.length} jobs',
                ),
                const SizedBox(height: 16),
                for (final entry in jobs.asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('job-${entry.value.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) =>
                          _confirmDeleteJob(context, ref, entry.value),
                      background: _DeleteBackground(
                        color: theme.colorScheme.error,
                      ),
                      child: _JobCard(
                        job: entry.value,
                        index: entry.key,
                        onTap: () => ref
                            .read(navigatorProvider)
                            .goToJobDetail(entry.value.id),
                      ),
                    ),
                  ),
                _ListFooter(state: state),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmDeleteJob(
    BuildContext context,
    WidgetRef ref,
    Job job,
  ) async {
    final controller = ref.read(jobListControllerProvider);
    List<CandidateResult> candidates;
    try {
      candidates = await controller.candidatesFor(job.id);
    } catch (_) {
      candidates = const [];
    }
    if (!context.mounted) return false;

    final confirmed = await showDeleteConfirm(
      context,
      title: 'Delete this job?',
      message: candidates.isEmpty
          ? 'This job has no candidates. It will be permanently removed.'
          : 'This job and its ${candidates.length} '
              '${candidates.length == 1 ? 'candidate' : 'candidates'} '
              'will be permanently removed.',
      details: [jobDeleteDetails(job, candidates)],
      confirmLabel: 'Delete job',
    );
    if (!confirmed) return false;

    try {
      await controller.deleteJob(job.id);
      if (!context.mounted) return false;
      await showActionResult(
        context,
        success: true,
        title: 'Job deleted',
        message: "'${job.title}' was permanently removed.",
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      await showActionResult(
        context,
        success: false,
        title: 'Delete failed',
        message: '$e',
      );
      return false;
    }
  }
}

/// Red swipe-reveal background shown behind a job card during a swipe.
class _DeleteBackground extends StatelessWidget {
  final Color color;

  const _DeleteBackground({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}

/// Bottom-of-list indicator: a spinner while the next page is being fetched,
/// and a "no more data" message once the backend has nothing left to return.
class _ListFooter extends StatelessWidget {
  final JobListState state;

  const _ListFooter({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No more jobs',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Shimmering placeholder that mirrors the layout of [_JobCard]: avatar,
/// title, date, candidate count, and chevron grey areas.
class _JobCardSkeleton extends StatelessWidget {
  const _JobCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer(
          child: Row(
            children: [
              const ShimmerBox(width: 48, height: 48, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 16, width: double.infinity),
                    SizedBox(height: 12),
                    ShimmerBox(height: 12, width: 140),
                    SizedBox(height: 12),
                    ShimmerBox(height: 12, width: 96),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ShimmerBox(width: 20, height: 20, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final int index;
  final VoidCallback onTap;

  const _JobCard({
    required this.job,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = avatarColor(index);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape(theme),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            formatCreatedAt(job.createdAt),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${job.candidateCount} candidates',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

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
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_off_outlined,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text('No jobs yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your first job and start ranking candidates.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('Cannot reach the backend.\n$message',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
