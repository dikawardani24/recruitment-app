import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../domain/models.dart';
import '../domain/usecases/delete_job.dart';
import '../providers.dart';

/// Owns the job list actions. The list has no busy/loading UI state, so this
/// is a plain controller instead of a [Notifier].
class JobListController {
  JobListController(this._ref);

  final Ref _ref;

  Future<void> refresh() {
    return _ref.read(jobsProvider.notifier).refresh();
  }

  Future<void> loadMore() {
    return _ref.read(jobsProvider.notifier).loadMore();
  }

  /// Candidates of [jobId], fetched on demand so a delete confirmation can
  /// preview exactly what will be removed.
  Future<List<CandidateResult>> candidatesFor(String jobId) {
    return _ref.read(cvsProvider(jobId).future);
  }

  /// Deletes the job server-side, then reloads the list from page 1.
  Future<void> deleteJob(String jobId) async {
    await getIt<DeleteJob>()(jobId);
    await refresh();
  }
}

final jobListControllerProvider =
    Provider<JobListController>((ref) => JobListController(ref));
