import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_ats/controllers/upload/upload_controller.dart';
import 'package:ai_ats/di.dart';
import 'package:ai_ats/domain/models/import_result.dart';
import 'package:ai_ats/domain/usecases/upload_cvs.dart';

/// Records each batch and can be told to fail uploads of specific files.
class _FakeUploadCvs implements UploadCvs {
  final batches = <List<String>>[]; // file names per batch
  final importIds = <String?>[];
  Set<String> failNames = {}; // file names that always throw

  @override
  Future<ImportResponse> call(
    String jobId, {
    String? importId,
    required List<File> files,
    ProgressCallback? onSendProgress,
  }) async {
    batches.add(files.map((f) => f.path.split('/').last).toList());
    importIds.add(importId);
    if (files.any((f) => failNames.contains(f.path.split('/').last))) {
      throw Exception('network down');
    }
    return ImportResponse(
      importId: 'imp-1',
      jobId: jobId,
      status: 'submitted',
      totalFiles: files.length,
      batchFiles: files.length,
    );
  }
}

void main() {
  late _FakeUploadCvs fake;
  late ProviderContainer container;

  setUp(() {
    fake = _FakeUploadCvs();
    getIt.registerLazySingleton<UploadCvs>(() => fake);
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    getIt.unregister<UploadCvs>();
  });

  List<File> makeFiles(int n) =>
      List.generate(n, (i) => File('/tmp/upload_controller/cv_$i.pdf'));

  Set<String> namesOf(List<File> files, int start, int end) =>
      {for (var i = start; i < end; i++) 'cv_$i.pdf'};

  test('splits 45 files into ceil(45/20) batches', () async {
    await container
        .read(uploadControllerProvider.notifier)
        .start('job-1', makeFiles(45));

    expect(fake.batches.length, 3);
    expect(fake.batches[0].length, 20);
    expect(fake.batches[1].length, 20);
    expect(fake.batches[2].length, 5);
    expect(fake.importIds[0], isNull); // first batch starts a new import
    expect(fake.importIds[1], 'imp-1'); // subsequent batches append
    expect(fake.importIds[2], 'imp-1');

    final state = container.read(uploadControllerProvider);
    expect(state.completed, isTrue);
    expect(state.uploadedFiles, 45);
    expect(state.failedFiles, 0);
    expect(state.totalBatches, 3);
  });

  test('single batch uploads everything at once', () async {
    await container
        .read(uploadControllerProvider.notifier)
        .start('job-1', makeFiles(3));

    expect(fake.batches.length, 1);
    expect(fake.batches.first.length, 3);

    final state = container.read(uploadControllerProvider);
    expect(state.completed, isTrue);
    expect(state.uploadedFiles, 3);
    expect(state.failedFiles, 0);
  });

  test('failing batch is retried then reported as failed', () async {
    final files = makeFiles(25);
    fake.failNames = namesOf(files, 20, 25);

    await container
        .read(uploadControllerProvider.notifier)
        .start('job-1', files);

    final state = container.read(uploadControllerProvider);
    expect(state.completed, isTrue);
    expect(state.uploadedFiles, 20);
    expect(state.failedFiles, 5);
    // batch 1 uploaded once; batch 2 attempted twice (one retry) then failed
    expect(fake.batches.length, 3);
    expect(fake.batches[1], fake.batches[2]); // retry sent the same files
  });

  test('retryFailed re-uploads previously failed files', () async {
    final files = makeFiles(45);
    fake.failNames = namesOf(files, 20, 40);
    final controller = container.read(uploadControllerProvider.notifier);

    await controller.start('job-1', files);
    expect(container.read(uploadControllerProvider).failedFiles, 20);
    expect(container.read(uploadControllerProvider).uploadedFiles, 25);

    fake.failNames = {}; // retry should succeed
    await controller.retryFailed('job-1');

    final state = container.read(uploadControllerProvider);
    expect(state.uploadedFiles, 45);
    expect(state.failedFiles, 0);
    expect(state.completed, isTrue);
    // retries reuse the same import so files are appended to it
    expect(fake.importIds.last, 'imp-1');
  });

  test('empty file list produces an error state, not an upload', () async {
    await container
        .read(uploadControllerProvider.notifier)
        .start('job-1', []);

    final state = container.read(uploadControllerProvider);
    expect(state.error, 'No files selected');
    expect(fake.batches, isEmpty);
  });
}
