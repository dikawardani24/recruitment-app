import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../domain/models.dart';
import '../../domain/usecases/create_job.dart';
import '../../providers.dart';
import 'job_form_state.dart';
import 'picked_jd_file.dart';

/// Owns the job creation action. File picking, the API call, feedback, and
/// navigation are all handled here; the screen only binds form fields.
class JobFormController extends Notifier<JobFormState> {
  @override
  JobFormState build() => const JobFormState();

  /// Lets the user pick a JD file. Text/markdown files are read so their
  /// content can pre-fill the description; other formats are returned for
  /// upload as-is. Returns `null` when the user cancels.
  Future<PickedJdFile?> pickJdFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'md'],
    );
    if (result == null || result.files.single.path == null) return null;
    final file = File(result.files.single.path!);
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();

    String? description;
    if (ext == 'txt' || ext == 'md' || ext == 'text') {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) description = content;
      } catch (_) {
        // Ignore read errors — the user can still type the description.
      }
    }
    return PickedJdFile(file: file, name: name, description: description);
  }

  /// Creates the job and reports the outcome with a snackbar. The form's own
  /// validation feedback is left to the widget; everything after that runs
  /// here.
  Future<void> submit(
    BuildContext context, {
    required String title,
    required String description,
    File? jdFile,
    String? jdFileName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final job = await createJob(
        title: title,
        description: description,
        jdFile: jdFile,
        jdFileName: jdFileName,
      );
      _showJobCreated(messenger, job);
    } catch (e) {
      _showJobCreateFailed(messenger, e);
    }
  }

  /// Snackbar confirming the job was created.
  void _showJobCreated(ScaffoldMessengerState messenger, Job job) {
    messenger.showSnackBar(SnackBar(content: Text('Created "${job.title}"')));
  }

  /// Snackbar reporting a failed job creation.
  void _showJobCreateFailed(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to create job: $error')),
    );
  }

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
      final job = await getIt<CreateJob>()(
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
