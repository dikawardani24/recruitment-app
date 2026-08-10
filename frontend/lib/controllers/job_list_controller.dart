import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../domain/models.dart';
import '../domain/usecases/delete_job.dart';
import '../navigation/app_navigator.dart';
import '../providers.dart';
import '../screens/delete_confirm_screen.dart';

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

  /// Deletes [job] end to end: fetches its candidates, asks for confirmation,
  /// deletes it server-side, and shows a result page. Resolves to `true` only
  /// when the job was actually deleted.
  Future<bool> deleteJob(Job job) async {
    List<CandidateResult> candidates;
    try {
      candidates = await candidatesFor(job.id);
    } catch (_) {
      candidates = const [];
    }

    final confirmed = await _confirmDeleteJob(job, candidates);
    if (!confirmed) return false;

    try {
      await removeJob(job.id);
      await _showJobDeleted(job);
      return true;
    } catch (e) {
      await _showJobDeleteFailed(e);
      return false;
    }
  }

  /// Deletes the job server-side, then reloads the list from page 1.
  Future<void> removeJob(String jobId) async {
    await getIt<DeleteJob>()(jobId);
    await refresh();
  }

  /// Confirm dialog before deleting a whole job.
  Future<bool> _confirmDeleteJob(
    Job job,
    List<CandidateResult> candidates,
  ) {
    return _ref.read(navigatorProvider).pushDeleteConfirm(
      DeleteConfirmData(
        title: 'Delete this job?',
        message: candidates.isEmpty
            ? 'This job has no candidates. It will be permanently removed.'
            : 'This job and its ${candidates.length} '
                  '${candidates.length == 1 ? 'candidate' : 'candidates'} '
                  'will be permanently removed.',
        details: [jobDeleteDetails(job, candidates)],
      ),
    );
  }

  /// Result page after a successful job deletion.
  Future<void> _showJobDeleted(Job job) {
    return _ref.read(navigatorProvider).pushActionResult(
      ActionResultData(
        success: true,
        title: 'Job deleted',
        message: "'${job.title}' was permanently removed.",
      ),
    );
  }

  /// Result page after a failed job deletion.
  Future<void> _showJobDeleteFailed(Object error) {
    return _ref.read(navigatorProvider).pushActionResult(
      ActionResultData(
        success: false,
        title: 'Delete failed',
        message: '$error',
      ),
    );
  }

  void openSettings() => _ref.read(navigatorProvider).goToSettings();

  void openJobForm() => _ref.read(navigatorProvider).goToJobForm();

  void openJobDetail(String jobId) =>
      _ref.read(navigatorProvider).goToJobDetail(jobId);

  void openChucker() => ChuckerFlutter.showChuckerScreen();
}

final jobListControllerProvider = Provider<JobListController>(
  (ref) => JobListController(ref),
);
