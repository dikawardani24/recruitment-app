import 'dart:async';

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
  Timer? _pollingTimer;
  String? _pollingJobId;
  String? _pollingImportId;
  bool _pollInProgress = false;

  @override
  JobDetailState build() {
    ref.onDispose(_cancelPolling);
    return const JobDetailState();
  }

  void _start(String message) =>
      state = JobDetailState(busy: true, loadingMessage: message);

  void _stop() => state = const JobDetailState();

  Future<void> refreshCvs(String jobId) async {
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(jobsProvider);
    await ref.read(cvsProvider(jobId).future);
  }

  /// Starts refreshing CVs only after the backend has accepted an import.
  /// A new import replaces any previous loop, and the loop is cancelled as
  /// soon as no CV is still processing.
  void startPolling(String jobId, String importId) {
    if (importId.trim().isEmpty) return;
    _cancelPolling();
    _pollingJobId = jobId;
    _pollingImportId = importId;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_poll(jobId, importId));
    });
  }

  void stopPolling(String jobId) {
    if (_pollingJobId == jobId) _cancelPolling();
  }

  Future<void> _poll(String jobId, String importId) async {
    if (_pollInProgress ||
        _pollingJobId != jobId ||
        _pollingImportId != importId) {
      return;
    }
    _pollInProgress = true;
    try {
      await refreshCvs(jobId);
      if (_pollingJobId != jobId || _pollingImportId != importId) return;
      final cvs =
          ref.read(cvsProvider(jobId)).value ?? const <CandidateResult>[];
      final hasPendingProcessing = cvs.any(
        (candidate) =>
            candidate.status == 'uploaded' || candidate.status == 'processing',
      );
      if (!hasPendingProcessing) _cancelPolling();
    } catch (_) {
      // A transient polling error must not create another loop. The existing
      // timer is retained so an active import can recover on the next tick.
    } finally {
      _pollInProgress = false;
    }
  }

  void _cancelPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingJobId = null;
    _pollingImportId = null;
    _pollInProgress = false;
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
