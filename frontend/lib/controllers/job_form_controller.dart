import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../providers.dart';

/// UI-busy state for the job form screen.
class JobFormState {
  final bool submitting;
  final String? loadingMessage;

  const JobFormState({this.submitting = false, this.loadingMessage});
}

/// Owns the job creation action. Navigation is performed here via
/// [navigatorProvider]; the screen handles form validation, file picking,
/// and snackbars.
class JobFormController extends Notifier<JobFormState> {
  @override
  JobFormState build() => const JobFormState();

  Future<Job> createJob({
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) async {
    state = const JobFormState(
      submitting: true,
      loadingMessage: 'Creating job…',
    );
    try {
      final job = await ref.read(apiClientProvider).createJob(
            title: title,
            description: description,
            jdFile: jdFile,
            jdFileName: jdFileName,
          );
      ref.invalidate(jobsProvider);
      ref.read(navigatorProvider).pop();
      return job;
    } finally {
      state = const JobFormState();
    }
  }
}

final jobFormControllerProvider =
    NotifierProvider<JobFormController, JobFormState>(JobFormController.new);
