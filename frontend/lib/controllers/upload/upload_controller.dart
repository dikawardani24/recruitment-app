import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import '../../domain/usecases/upload_cvs.dart';
import 'upload_state.dart';

/// Number of CVs uploaded per HTTP request. Configurable at build time with
/// `--dart-define=CV_BATCH_SIZE=20`.
const int cvUploadBatchSize = int.fromEnvironment(
  'CV_BATCH_SIZE',
  defaultValue: 20,
);

/// How many times a failing batch is retried before being counted as failed.
const int maxUploadAttempts = 2;

const Duration uploadRetryDelay = Duration(milliseconds: 600);

/// Drives batched CV uploads: splits files into batches, uploads each batch,
/// reports progress, and auto-retries failed batches. Extraction/processing
/// happens on the backend afterwards; the recruiter can leave this page once
/// uploads are submitted.
class UploadController extends Notifier<UploadState> {
  List<File> _failedFiles = const [];
  String? _importId;

  @override
  UploadState build() => const UploadState();

  Future<void> start(String jobId, List<File> files) async {
    if (files.isEmpty) {
      state = const UploadState(error: 'No files selected');
      return;
    }
    _failedFiles = [];
    _importId = null;
    state = UploadState(
      uploading: true,
      totalFiles: files.length,
      totalBatches: _batchCount(files.length),
    );
    await _upload(jobId, files);
  }

  /// Re-attempts uploads that failed during the last run. Keeps the existing
  /// import so retried files are appended rather than creating a new one.
  Future<void> retryFailed(String jobId) async {
    final failed = _failedFiles;
    if (failed.isEmpty || state.uploading) return;
    _failedFiles = [];
    state = state.copyWith(
      uploading: true,
      completed: false,
      totalBatches: _batchCount(failed.length),
      currentBatch: 0,
      batchProgress: 0,
      error: null,
    );
    await _upload(jobId, failed);
  }

  Future<void> _upload(String jobId, List<File> files) async {
    var uploaded = state.uploadedFiles;
    var failed = 0; // failures in this run only

    for (var i = 0; i < files.length; i += cvUploadBatchSize) {
      final end = min(i + cvUploadBatchSize, files.length);
      final batch = files.sublist(i, end);
      final batchNumber = i ~/ cvUploadBatchSize + 1;

      state = state.copyWith(
        currentBatch: batchNumber,
        batchProgress: 0,
        uploading: true,
      );

      var succeeded = false;
      for (var attempt = 0; attempt < maxUploadAttempts; attempt++) {
        try {
          final resp = await getIt<UploadCvs>()(
            jobId,
            importId: _importId,
            files: batch,
            onSendProgress: (sent, total) {
              if (total > 0) {
                state = state.copyWith(batchProgress: sent / total);
              }
            },
          );
          _importId ??= resp.importId;
          uploaded += batch.length;
          succeeded = true;
          break;
        } catch (_) {
          if (attempt < maxUploadAttempts - 1) {
            await Future<void>.delayed(uploadRetryDelay);
          }
        }
      }

      if (!succeeded) {
        failed += batch.length;
        _failedFiles = [..._failedFiles, ...batch];
      }
      state = state.copyWith(uploadedFiles: uploaded, failedFiles: failed);
    }

    state = state.copyWith(uploading: false, completed: true);
  }

  static int _batchCount(int fileCount) =>
      fileCount == 0 ? 0 : (fileCount / cvUploadBatchSize).ceil();
}

final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(UploadController.new);
