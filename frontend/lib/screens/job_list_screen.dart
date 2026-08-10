import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../controllers/job_list_controller.dart';
import '../providers.dart';
import '../widgets/delete_background.dart';
import '../widgets/error_view.dart';
import '../widgets/gradient_header.dart';
import '../widgets/job_card.dart';
import '../widgets/job_list_footer.dart';

export '../widgets/job_card.dart' show formatCreatedAt;

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: jobListController.openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Open Chucker Flutter',
            onPressed: jobListController.openChucker,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'copilot',
            onPressed: jobListController.openChat,
            icon: const Icon(Icons.support_agent),
            label: const Text('Copilot'),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'new-job',
            onPressed: jobListController.openJobForm,
            icon: const Icon(Icons.add),
            label: const Text('New job'),
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const JobCardSkeleton(),
        ),
        error: (e, _) => ErrorView(message: '$e', onRetry: jobListController.refresh),
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
                _SearchJobsCard(onTap: jobListController.openJobSearch),
                const SizedBox(height: 16),
                for (final entry in jobs.asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('job-${entry.value.id}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) =>
                          jobListController.deleteJob(entry.value),
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
                JobListFooter(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchJobsCard extends StatelessWidget {
  const _SearchJobsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Search jobs',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
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
