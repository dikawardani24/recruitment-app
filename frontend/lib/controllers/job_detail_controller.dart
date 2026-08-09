import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../domain/models.dart';
import '../domain/usecases/delete_candidate.dart';
import '../domain/usecases/delete_job.dart';
import '../domain/usecases/rank_cv.dart';
import '../domain/usecases/rank_job.dart';
import '../navigation/app_navigator.dart';
import '../providers.dart';
import '../screens/action_result_screen.dart';
import '../screens/delete_confirm_screen.dart';
import '../widgets/candidate_detail_sheet.dart';
import '../widgets/cv_upload_overlay.dart';
import 'upload_controller.dart';

/// UI-busy state for the job detail screen, owned here instead of via local
/// hooks so the action methods can live outside the widget.
class JobDetailState {
  final bool busy;
  final String? loadingMessage;

  const JobDetailState({this.busy = false, this.loadingMessage});
}

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

/// Owns every job detail action end to end: confirmations, API calls (via
/// [JobDetailNotifier]), result/error feedback, and navigation. The screen
/// only picks files and hands the rest to these methods.
class JobDetailController {
  final Ref _ref;

  JobDetailController(this._ref);

  JobDetailNotifier get _notifier => _ref.read(jobDetailStateProvider.notifier);

  Future<void> refreshCvs(String jobId) => _notifier.refreshCvs(jobId);

  /// Ranks all candidates. Shows a dialog when there is nothing to rank, asks
  /// before re-ranking an already-ranked set, then navigates to the ranking
  /// page on success.
  Future<void> rank(
    BuildContext context,
    String jobId,
    List<CandidateResult> cvs,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (cvs.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('No candidates to rank'),
          content: const Text(
            'Add CVs first, then tap "Rank CVs" to score the candidates.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final allRanked = cvs.every((c) => c.status == 'ranked');
    if (allRanked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Re-rank all candidates?'),
          content: Text(
            'All ${cvs.length} '
            '${cvs.length == 1 ? 'candidate has' : 'candidates have'} '
            'already been ranked. Re-run ranking on all of them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Re-rank all'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final hasReady = cvs.any(
      (c) => c.status == 'completed' || c.status == 'ranked',
    );
    if (!hasReady) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ranking unavailable'),
          content: const Text(
            'No candidates are ready to rank yet. Wait until CV processing '
            'finishes before ranking.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final response = await _notifier.rankJob(jobId);
      if (!context.mounted) return;
      final title = _ref.read(jobProvider(jobId)).value?.title ?? 'Job';
      _ref
          .read(navigatorProvider)
          .goToRankings(
            RankingsScreenData(
              jobId: jobId,
              jobTitle: title,
              source: response.source,
            ),
          );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Ranking failed: $e')));
    }
  }

  /// Ranks a single CV. Resolves to `true` only when ranking succeeded so the
  /// detail sheet can close itself.
  Future<bool> rankCv(
    BuildContext context,
    String jobId,
    CandidateResult cv,
  ) async {
    final ready = cv.status == 'completed' || cv.status == 'ranked';
    final cvId = cv.cvId;
    if (!ready || cvId == null) {
      if (!context.mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ranking unavailable'),
          content: const Text(
            'This candidate is not ready to rank yet. Wait until CV '
            'processing finishes before ranking.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }
    try {
      await _notifier.rankCv(jobId, cvId);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ranking failed: $e')));
      }
      return false;
    }
  }

  /// Opens the candidate detail bottom sheet. When [onRank] is provided the
  /// sheet can trigger [rankCv] directly, keeping the screen decoupled.
  void openCandidateDetails(
    BuildContext context,
    CandidateResult cv, {
    Future<bool> Function()? onRank,
  }) {
    showCandidateDetailSheet(context, cv, onRank: onRank);
  }

  /// Deletes the whole job: confirms, calls the API, shows a result page, then
  /// navigates back to the job list.
  Future<void> deleteJob(
    BuildContext context,
    String jobId,
    Job job,
    List<CandidateResult> candidates,
  ) async {
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
    if (!confirmed) return;
    try {
      await _notifier.deleteJob(jobId);
      if (!context.mounted) return;
      await showActionResult(
        context,
        success: true,
        title: 'Job deleted',
        message: "'${job.title}' was permanently removed.",
      );
    } catch (e) {
      if (!context.mounted) return;
      await showActionResult(
        context,
        success: false,
        title: 'Delete failed',
        message: '$e',
      );
      return;
    }
    if (!context.mounted) return;
    _ref.read(navigatorProvider).goToJobs();
  }

  /// Deletes a single candidate: confirms, calls the API, shows a result page.
  /// Resolves to `true` on success so the swipe can complete.
  Future<bool> deleteCv(
    BuildContext context,
    String jobId,
    CandidateResult cv,
  ) async {
    final cvId = cv.cvId;
    if (cvId == null) return false;
    final name = cv.candidateName ?? cv.fileName;
    final confirmed = await showDeleteConfirm(
      context,
      title: 'Delete this candidate?',
      message: 'This candidate and their CV will be permanently removed.',
      details: [candidateDeleteDetails(cv)],
      confirmLabel: 'Delete candidate',
    );
    if (!confirmed) return false;
    try {
      await _notifier.deleteCv(jobId, cvId);
      if (!context.mounted) return false;
      await showActionResult(
        context,
        success: true,
        title: 'Candidate deleted',
        message: "'$name' and their CV were permanently removed.",
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

  /// Lets the user pick CV files and submits them for upload. File selection
  /// lives here so the screen only renders UI.
  Future<void> pickCvs(BuildContext context, String jobId) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();
    if (files.isEmpty) return;
    if (!context.mounted) return;
    await submitCvs(context, jobId, files);
  }

  /// Submits uploaded CVs: starts the batched upload, shows the progress
  /// overlay, refreshes the list, and reports the result.
  Future<void> submitCvs(
    BuildContext context,
    String jobId,
    List<File> files,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    _ref.read(uploadControllerProvider.notifier).start(jobId, files);
    await showCvUploadOverlay(context, jobId);
    if (!context.mounted) return;
    await refreshCvs(jobId);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${files.length} CV(s) submitted. Processing continues in the background.',
        ),
      ),
    );
  }

  /// Opens the full ranking page for an already-ranked set of candidates.
  void viewRankings(String jobId, String jobTitle, String source) {
    _ref
        .read(navigatorProvider)
        .goToRankings(
          RankingsScreenData(jobId: jobId, jobTitle: jobTitle, source: source),
        );
  }
}

final jobDetailStateProvider =
    NotifierProvider<JobDetailNotifier, JobDetailState>(JobDetailNotifier.new);

final jobDetailControllerProvider = Provider<JobDetailController>(
  (ref) => JobDetailController(ref),
);
