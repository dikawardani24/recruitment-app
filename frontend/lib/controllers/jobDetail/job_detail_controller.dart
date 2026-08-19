import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../navigation/app_navigator.dart';
import '../../providers.dart';
import '../../screens/delete_confirm_screen.dart';
import '../../widgets/cv_upload_overlay.dart';
import '../upload/upload_controller.dart';
import '../deleteConfirm/delete_confirm_controller.dart';
import '../api_key_controller.dart';
import 'job_detail_notifier.dart';

/// Owns every job detail action end to end: confirmations, API calls (via
/// [JobDetailNotifier]), result/error feedback, and navigation. The screen
/// only picks files and hands the rest to these methods.
class JobDetailController {
  final Ref _ref;

  JobDetailController(this._ref);

  JobDetailNotifier get _notifier => _ref.read(jobDetailStateProvider.notifier);

  Future<void> refreshCvs(String jobId) => _notifier.refreshCvs(jobId);

  void stopPolling(String jobId) => _notifier.stopPolling(jobId);

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
      await _showNoCandidatesDialog(context);
      return;
    }

    final allRanked = cvs.every((c) => c.status == 'ranked');
    if (allRanked) {
      final confirmed = await _showReRankConfirmDialog(context, cvs.length);
      if (confirmed != true) return;
    }

    final hasReady = cvs.any(
      (c) => c.status == 'completed' || c.status == 'ranked',
    );
    if (!hasReady) {
      if (!context.mounted) return;
      await _showRankingUnavailableDialog(context);
      return;
    }

    try {
      final keys = _ref.read(apiKeyProvider);
      final apiKey =
          keys[ApiKeyProvider.gemini.id] ?? keys[ApiKeyProvider.openrouter.id];

      final response = await _notifier.rankJob(jobId, apiKey: apiKey);
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
      await _showRankingUnavailableDialog(
        context,
        message:
            'This candidate is not ready to rank yet. Wait until CV '
            'processing finishes before ranking.',
      );
      return false;
    }
    try {
      final keys = _ref.read(apiKeyProvider);
      final apiKey =
          keys[ApiKeyProvider.gemini.id] ?? keys[ApiKeyProvider.openrouter.id];

      await _notifier.rankCv(jobId, cvId, apiKey: apiKey);
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

  /// Opens the candidate detail page. Deleting and ranking are handled by the
  /// page itself through this controller.
  void openCandidateDetails(
    BuildContext context,
    String jobId,
    CandidateResult cv,
  ) {
    _ref.read(navigatorProvider).goToCandidateDetail(jobId, cv);
  }

  /// Deletes the whole job: confirms, calls the API, shows a result page, then
  /// navigates back to the job list.
  Future<void> deleteJob(
    String jobId,
    Job job,
    List<CandidateResult> candidates,
  ) async {
    final deleteFlow = _ref.read(deleteConfirmControllerProvider.notifier);
    deleteFlow.prepare(
      onConfirm: () => _notifier.deleteJob(jobId),
      successResult: ActionResultData(
        success: true,
        title: 'Job deleted',
        message: "'${job.title}' was permanently removed.",
      ),
    );

    await _ref
        .read(navigatorProvider)
        .pushDeleteConfirm(
          DeleteConfirmArgs(
            data: DeleteConfirmData(
              title: 'Delete this job?',
              message: candidates.isEmpty
                  ? 'This job has no candidates. It will be permanently removed.'
                  : 'This job and its ${candidates.length} '
                        '${candidates.length == 1 ? 'candidate' : 'candidates'} '
                        'will be permanently removed.',
              details: [jobDeleteDetails(job, candidates)],
            ),
            onDeleted: () async {
              _ref.read(navigatorProvider).goToJobs();
            },
          ),
        );
  }

  /// Deletes a single candidate: confirms, calls the API, shows a result page.
  /// Resolves to `true` on success so the swipe can complete.
  Future<bool> deleteCv(String jobId, CandidateResult cv) async {
    final cvId = cv.cvId;
    if (cvId == null) return false;
    final name = cv.candidateName ?? cv.fileName;
    final deleteFlow = _ref.read(deleteConfirmControllerProvider.notifier);
    deleteFlow.prepare(
      onConfirm: () => _notifier.deleteCv(jobId, cvId),
      successResult: ActionResultData(
        success: true,
        title: 'Candidate deleted',
        message: "'$name' and their CV were permanently removed.",
      ),
    );

    return _ref
        .read(navigatorProvider)
        .pushDeleteConfirm(
          DeleteConfirmArgs(
            data: DeleteConfirmData(
              title: 'Delete this candidate?',
              message:
                  'This candidate and their CV will be permanently removed.',
              details: [candidateDeleteDetails(cv)],
            ),
          ),
        );
  }

  /// Lets the user pick CV files and submits them for upload. File selection
  /// lives here so the screen only renders UI.
  Future<void> pickCvs(BuildContext context, String jobId) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .where((f) => f.bytes?.isNotEmpty ?? false)
        .map((f) => UploadFile(name: f.name, bytes: f.bytes!))
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
    List<UploadFile> files,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final upload = _ref
        .read(uploadControllerProvider.notifier)
        .start(jobId, files);
    await showCvUploadOverlay(context, jobId);
    final importId = await upload;
    if (!context.mounted) return;
    if (importId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('CV upload failed. Please try again.')),
      );
      return;
    }
    await refreshCvs(jobId);
    _notifier.startPolling(jobId, importId);
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

  /// Info dialog shown when there are no CVs to rank yet.
  Future<void> _showNoCandidatesDialog(BuildContext context) {
    return showDialog<void>(
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
  }

  /// Confirm dialog shown before re-ranking a set that is already fully
  /// ranked. Resolves to `true` when the user wants to re-rank.
  Future<bool?> _showReRankConfirmDialog(BuildContext context, int count) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Re-rank all candidates?'),
        content: Text(
          'All $count '
          '${count == 1 ? 'candidate has' : 'candidates have'} '
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
  }

  /// Info dialog shown when nothing is ready to rank yet.
  Future<void> _showRankingUnavailableDialog(
    BuildContext context, {
    String message =
        'No candidates are ready to rank yet. Wait until CV '
        'processing finishes before ranking.',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ranking unavailable'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

final jobDetailControllerProvider = Provider<JobDetailController>(
  (ref) => JobDetailController(ref),
);
