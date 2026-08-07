import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_navigator.dart';
import '../providers.dart';

/// UI-busy state for the job detail screen, owned here instead of via local
/// hooks so the action methods can live outside the widget.
class JobDetailState {
  final bool busy;
  final String? loadingMessage;

  const JobDetailState({this.busy = false, this.loadingMessage});
}

/// Owns the job detail actions: refreshing CVs, uploading CVs, and ranking
/// candidates. Navigation is performed here via [navigatorProvider]; the
/// screen only handles file picking and snackbars.
class JobDetailController extends Notifier<JobDetailState> {
  @override
  JobDetailState build() => const JobDetailState();

  void _start(String message) =>
      state = JobDetailState(busy: true, loadingMessage: message);

  void _stop() => state = const JobDetailState();

  Future<void> refreshCvs(String jobId) async {
    ref.invalidate(cvsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }

  Future<int> uploadCvs(String jobId, List<File> files) async {
    _start('Uploading ${files.length} CV(s)…');
    try {
      final uploaded =
          await ref.read(apiClientProvider).uploadCvs(jobId, files);
      await refreshCvs(jobId);
      return uploaded.length;
    } finally {
      _stop();
    }
  }

  Future<void> rank(String jobId) async {
    _start('Ranking candidates…');
    try {
      final response = await ref.read(apiClientProvider).rankJob(jobId);
      await refreshCvs(jobId);
      final title = ref.read(jobProvider(jobId)).value?.title ?? 'Job';
      ref.read(navigatorProvider).goToRankings(
            RankingsScreenData(
              jobId: jobId,
              jobTitle: title,
              source: response.source,
            ),
          );
    } finally {
      _stop();
    }
  }

  /// Deletes a single candidate and refreshes the CV list and rankings.
  Future<void> deleteCv(String jobId, String cvId) async {
    await ref.read(apiClientProvider).deleteCandidate(jobId, cvId);
    ref.invalidate(cvsProvider(jobId));
    ref.invalidate(rankingsProvider(jobId));
    await ref.read(cvsProvider(jobId).future);
  }

  /// Deletes the whole job, reloads the job list, and returns to it.
  Future<void> deleteJob(String jobId) async {
    _start('Deleting job…');
    try {
      await ref.read(apiClientProvider).deleteJob(jobId);
      await ref.read(jobsProvider.notifier).refresh();
      ref.read(navigatorProvider).goToJobs();
    } finally {
      _stop();
    }
  }
}

final jobDetailControllerProvider =
    NotifierProvider<JobDetailController, JobDetailState>(
  JobDetailController.new,
);
