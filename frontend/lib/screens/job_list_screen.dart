import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers.dart';
import '../router.dart';

class JobListScreen extends HookConsumerWidget {
  const JobListScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(jobsProvider);
    await ref.read(jobsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(navigatorProvider).goToJobForm(),
        icon: const Icon(Icons.add),
        label: const Text('New job'),
      ),
      body: jobsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading jobs…'),
            ],
          ),
        ),
        error: (e, _) => _ErrorView(message: '$e', onRetry: () => _refresh(ref)),
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(
              child: Text('No jobs yet. Tap "New job" to create one.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(job.title),
                  subtitle: Text(
                    job.description.isEmpty
                        ? 'No description'
                        : (job.description.split('\n').first.length > 80
                            ? '${job.description.split('\n').first.substring(0, 80)}…'
                            : job.description.split('\n').first),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      ref.read(navigatorProvider).goToJobDetail(job.id),
                );
              },
            ),
          );
        },
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
