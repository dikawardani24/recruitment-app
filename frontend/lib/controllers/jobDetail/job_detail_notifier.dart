import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../domain/models.dart';
import '../../domain/usecases/delete_candidate.dart';
import '../../domain/usecases/delete_job.dart';
import '../../domain/usecases/rank_cv.dart';
import '../../domain/usecases/rank_job.dart';
import '../../providers.dart';
import 'job_detail_state.dart';

/// Runs the job detail domain operations. Every call flows through the
/// notifier: controller -> notifier -> usecase -> datasource -> api, keeping
/// usecases out of the screen. It only mutates state/refreshes providers and
/// never touches navigation, dialogs, or snackbars.
class JobDetailNotifier extends Notifier<JobDetailState> {
  @override
  JobDetailState build() => const JobDetailState();

  void _start(String message) =>
      state = JobDetailState(busy: true, loadingMessage: message);

  void _stop() => state = const JobDetailState();

  Future<void> refreshCvs(String jobId) async {
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(jobsProvider);
    await ref.read(cvsProvider(jobId).future);
  }

  /// Ranks every candidate and returns the response so the controller can
  /// navigate to the ranking page.
  Future<RankResponse> rankJob(String jobId) async {
    _start('Ranking candidates…');
    try {
      final response = await getIt<RankJob>()(jobId);
      ref.invalidate(rankingsProvider(jobId));
      await refreshCvs(jobId);
      return response;
    } finally {
      _stop();
    }
  }

  /// Ranks a single CV and refreshes the CV list and rankings.
  Future<void> rankCv(String jobId, String cvId) async {
    await getIt<RankCv>()(jobId, cvId);
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(rankingsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }

  /// Deletes a single candidate and refreshes the CV list and rankings.
  Future<void> deleteCv(String jobId, String cvId) async {
    await getIt<DeleteCandidate>()(jobId, cvId);
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(rankingsProvider(jobId));
    ref.invalidate(jobsProvider);
    await ref.read(cvsProvider(jobId).future);
  }

  /// Deletes the whole job and reloads the job list.
  Future<void> deleteJob(String jobId) async {
    _start('Deleting job…');
    try {
      await getIt<DeleteJob>()(jobId);
      await ref.read(jobsProvider.notifier).refresh();
    } finally {
      _stop();
    }
  }
}

final jobDetailStateProvider =
    NotifierProvider<JobDetailNotifier, JobDetailState>(JobDetailNotifier.new);
